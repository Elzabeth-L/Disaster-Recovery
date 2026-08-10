data "aws_iam_openid_connect_provider" "github" {
  arn = "arn:aws:iam::${var.expected_aws_account_id}:oidc-provider/token.actions.githubusercontent.com"
}

check "github_oidc_audience" {
  assert {
    condition     = contains(data.aws_iam_openid_connect_provider.github.client_id_list, "sts.amazonaws.com")
    error_message = "The existing GitHub OIDC provider must trust the sts.amazonaws.com audience."
  }
}

resource "aws_route53_zone" "project" {
  name          = local.hosted_zone_name
  comment       = "Delegated disaster-recovery lab zone; application records are managed by their owning states."
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = local.hosted_zone_name
  }
}

data "aws_iam_policy_document" "trust" {
  for_each = local.role_definitions

  statement {
    sid     = "GitHubActionsOidc"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = each.value.subjects
    }
  }
}

resource "aws_iam_role" "github" {
  for_each = local.role_definitions

  name                 = each.value.role_name
  description          = "GitHub Actions ${replace(each.key, "_", " ")} role for ${local.repository}."
  assume_role_policy   = data.aws_iam_policy_document.trust[each.key].json
  max_session_duration = 3600

  tags = {
    Name       = each.value.role_name
    Repository = local.repository
    Scope      = split("_", each.key)[0]
    Access     = split("_", each.key)[1]
  }
}

data "aws_iam_policy_document" "github" {
  for_each = local.role_definitions

  statement {
    sid       = "ListApprovedStateKeys"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [local.state_bucket_arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values = distinct(concat(
        each.value.readable_state_keys,
        each.value.writable_state_keys,
        [for key in each.value.lockable_state_keys : "${key}.tflock"],
      ))
    }
  }

  statement {
    sid     = "ReadApprovedState"
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:GetObjectVersion"]
    resources = [
      for key in distinct(concat(each.value.readable_state_keys, each.value.writable_state_keys)) : "${local.state_bucket_arn}/${key}"
    ]
  }

  statement {
    sid     = "ManageOwnedStateLocks"
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [
      for key in each.value.lockable_state_keys : "${local.state_bucket_arn}/${key}.tflock"
    ]
  }

  dynamic "statement" {
    for_each = length(each.value.writable_state_keys) > 0 ? [1] : []

    content {
      sid     = "WriteOwnedState"
      effect  = "Allow"
      actions = ["s3:PutObject", "s3:DeleteObject"]
      resources = [
        for key in each.value.writable_state_keys : "${local.state_bucket_arn}/${key}"
      ]
    }
  }

  statement {
    sid    = "DenyCrossOwnerStateWrites"
    effect = "Deny"
    actions = [
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:RestoreObject",
    ]
    resources = [
      for prefix in each.value.denied_prefixes : "${local.state_bucket_arn}/${prefix}"
    ]
  }

  statement {
    sid       = "ReadOwnedServiceMetadata"
    effect    = "Allow"
    actions   = local.read_actions
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = each.key == "shared_apply" ? [1] : []

    content {
      sid       = "ManageTemporaryRecoveryEgress"
      effect    = "Allow"
      actions   = local.shared_apply_actions
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = each.key == "eks_apply" ? [1] : []

    content {
      sid       = "ManageOwnedEksPlatform"
      effect    = "Allow"
      actions   = local.eks_apply_actions
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = each.key == "ec2_apply" ? [1] : []

    content {
      sid       = "ManageOwnedEc2Platform"
      effect    = "Allow"
      actions   = local.ec2_apply_actions
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = each.key == "ec2_apply" ? [1] : []

    content {
      sid       = "CreateRequiredEc2ServiceLinkedRoles"
      effect    = "Allow"
      actions   = ["iam:CreateServiceLinkedRole"]
      resources = ["*"]

      condition {
        test     = "StringEquals"
        variable = "iam:AWSServiceName"
        values   = ["elasticloadbalancing.amazonaws.com", "rds.amazonaws.com"]
      }
    }
  }

  dynamic "statement" {
    for_each = contains(["ec2_plan", "ec2_apply"], each.key) ? [1] : []

    content {
      sid       = "ReadOwnedEc2DatabaseSecret"
      effect    = "Allow"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = ["arn:aws:secretsmanager:*:${var.expected_aws_account_id}:secret:vaultrix-dr-*-ec2-db-credentials-*"]
    }
  }

  dynamic "statement" {
    for_each = each.key == "ec2_apply" ? [1] : []

    content {
      sid       = "PassOwnedEc2Roles"
      effect    = "Allow"
      actions   = ["iam:PassRole"]
      resources = ["arn:aws:iam::${var.expected_aws_account_id}:role/vaultrix-dr-*-ec2-*"]

      condition {
        test     = "StringEquals"
        variable = "iam:PassedToService"
        values   = ["backup.amazonaws.com", "ec2.amazonaws.com"]
      }
    }
  }

  dynamic "statement" {
    for_each = each.key == "eks_apply" ? [1] : []

    content {
      sid       = "PassOwnedEksRoles"
      effect    = "Allow"
      actions   = ["iam:PassRole"]
      resources = ["arn:aws:iam::${var.expected_aws_account_id}:role/vaultrix-dr-*-eks-*"]

      condition {
        test     = "StringEquals"
        variable = "iam:PassedToService"
        values   = ["ec2.amazonaws.com", "eks.amazonaws.com", "pods.eks.amazonaws.com"]
      }
    }
  }

  dynamic "statement" {
    for_each = length(each.value.dns_names) > 0 ? [1] : []

    content {
      sid       = "ChangeOwnedDnsRecords"
      effect    = "Allow"
      actions   = ["route53:ChangeResourceRecordSets"]
      resources = [aws_route53_zone.project.arn]

      condition {
        test     = "ForAllValues:StringLike"
        variable = "route53:ChangeResourceRecordSetsNormalizedRecordNames"
        values   = each.value.dns_names
      }

      condition {
        test     = "ForAllValues:StringEquals"
        variable = "route53:ChangeResourceRecordSetsRecordTypes"
        values   = ["A", "AAAA", "CNAME", "TXT"]
      }
    }
  }
}

resource "aws_iam_role_policy" "github" {
  for_each = local.role_definitions

  name   = "vaultrix-dr-owned-scope"
  role   = aws_iam_role.github[each.key].id
  policy = data.aws_iam_policy_document.github[each.key].json
}
