# Kubernetes delivery

The base manifests define the notes application, a single-replica PostgreSQL StatefulSet with an
encrypted retained EBS volume, an internet-facing ALB Ingress, disruption protection, restricted pod
security, resource limits, and default-deny network policy.

The protected deployment workflow supplies an immutable ECR image digest and creates the
`notes-database` Kubernetes Secret from AWS Secrets Manager without writing credentials to the
repository or Terraform state. Do not apply the checked-in `replace-me` image directly.
