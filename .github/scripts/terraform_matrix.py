#!/usr/bin/env python3
import json
import re
import sys


paths = [line.strip().replace("\\", "/") for line in sys.stdin if line.strip()]
validate_all = any(
    path in {
        ".github/workflows/terraform-pr.yml",
        ".github/scripts/terraform_matrix.py",
    }
    for path in paths
)

roots = (
    (
        "primary-shared",
        "terraform/environments/primary/shared",
        r"^terraform/environments/primary/shared/|^terraform/modules/regional-network/",
    ),
    (
        "dr-shared",
        "terraform/environments/dr/shared",
        r"^terraform/environments/dr/shared/|^terraform/modules/regional-network/",
    ),
    (
        "global-shared",
        "terraform/environments/global/shared",
        r"^terraform/environments/global/shared/",
    ),
    (
        "primary-ec2",
        "terraform/environments/primary/ec2",
        r"^terraform/environments/primary/ec2/|^terraform/modules/(alb|aws-backup|cloudwatch-alarms|ec2|rds)/|^docs/shared-infrastructure-contract\.md$",
    ),
    (
        "dr-ec2",
        "terraform/environments/dr/ec2",
        r"^terraform/environments/dr/ec2/|^terraform/modules/(alb|aws-backup|cloudwatch-alarms|ec2|rds)/|^docs/shared-infrastructure-contract\.md$",
    ),
    (
        "primary-eks",
        "terraform/environments/primary/eks",
        r"^terraform/environments/primary/eks/|^terraform/modules/eks-platform/|^docs/shared-infrastructure-contract\.md$",
    ),
    (
        "dr-eks",
        "terraform/environments/dr/eks",
        r"^terraform/environments/dr/eks/|^terraform/modules/eks-platform/|^docs/shared-infrastructure-contract\.md$",
    ),
)

include = [
    {"name": name, "path": root_path}
    for name, root_path, pattern in roots
    if validate_all or any(re.search(pattern, path) for path in paths)
]

print(json.dumps({"include": include}, separators=(",", ":")))
