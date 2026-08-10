# Human operator access

The project uses two Terraform-managed IAM users for interactive demonstrations. Neither user has
an access key. Sign in at `https://598120810297.signin.aws.amazon.com/console` with the temporary
password supplied out of band, then replace that password when prompted.

## EKS operator (Elzabeth-L)

User: `vaultrix-dr-eks-operator`

The user can launch CloudShell, discover only the two project clusters, and has cluster-admin access
inside each cluster through an EKS access entry.

Primary cluster:

```bash
aws eks update-kubeconfig --region ap-south-1 \
  --name vaultrix-dr-primary-eks --alias vaultrix-dr-primary-eks
kubectl get nodes
kubectl get pods -A
```

DR cluster:

```bash
aws eks update-kubeconfig --region ap-southeast-1 \
  --name vaultrix-dr-dr-eks --alias vaultrix-dr-dr-eks
kubectl get nodes
kubectl get pods -A
```

## EC2 operator (gokulk18)

User: `vaultrix-dr-ec2-operator`

The user can launch CloudShell, inspect EC2/Systems Manager status, and start Session Manager shells
only on instances tagged `Project=vaultrix-dr`.

Find and connect to the primary instance:

```bash
INSTANCE_ID=$(aws ec2 describe-instances --region ap-south-1 \
  --filters Name=tag:Project,Values=vaultrix-dr Name=tag:Application,Values=ec2 \
            Name=instance-state-name,Values=running \
  --query 'Reservations[0].Instances[0].InstanceId' --output text)
aws ssm start-session --region ap-south-1 --target "$INSTANCE_ID"
```

Inside the instance, verify the application:

```bash
sudo systemctl status vaultrix-app.service --no-pager
sudo docker ps
curl -fsS http://127.0.0.1:8080/health
```

For the DR instance, repeat the commands with Region `ap-southeast-1`.

## Credential rules

- Do not create access keys unless a later requirement explicitly needs them.
- Enable MFA for both users after their first login.
- Share Gokul's temporary password through an approved private channel, never GitHub or project files.
- Delete the login profile or disable the user after the demonstration if interactive access is no
  longer needed.
