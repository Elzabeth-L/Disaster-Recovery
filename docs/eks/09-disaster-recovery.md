# 09. EKS Disaster Recovery Mechanics — Technical Notes

## 1. Overview & Strategy Classification

The EKS Disaster Recovery architecture is classified as **Multi-Region Pilot-Light Recovery with CNAME Traffic Cutover**.

Unlike EC2 which can be stopped and started on demand, an **Amazon EKS Control Plane cannot be stopped or paused**. Therefore, the DR region (`ap-southeast-1`) maintains a permanently deployed, baseline EKS cluster (`vaultrix-dr-dr-eks`) ready to receive workloads.

```
+---------------------------------------------------------------------------------------------------+
| REGIONAL EKS DISASTER RECOVERY COMPARISON                                                         |
+--------------------------+----------------------------------+-------------------------------------+
| Characteristic           | Primary Region (ap-south-1)      | DR Region (ap-southeast-1)          |
+--------------------------+----------------------------------+-------------------------------------+
| EKS Cluster Name         | vaultrix-dr-primary-eks          | vaultrix-dr-dr-eks                  |
| Node Capacity            | 2 x t4g.medium (AL2023 ARM64)    | 2 x t4g.small (AL2023 ARM64)        |
| Ingress Hostname         | eks.dr.vaultrix.in               | eks-dr.dr.vaultrix.in (Diagnostic)  |
| PostgreSQL Database      | StatefulSet (8Gi gp3 EBS Volume) | StatefulSet (Seeded during Drill)   |
| Route 53 Cutover Mode    | CNAME Alias to Primary ALB       | CNAME Alias updated to DR ALB       |
+--------------------------+----------------------------------+-------------------------------------+
```

---

## 2. Automatic vs. Manual Responsibilities Matrix

```
+---------------------------------------------------------------------------------------------------+
| EKS DISASTER RECOVERY RESPONSIBILITY TRUTH TABLE                                                  |
+--------------------------+--------------------+---------------------------------------------------+
| Event / Operation        | Automatic / Manual | Technical Enforcing Mechanism                     |
+--------------------------+--------------------+---------------------------------------------------+
| Application Pod Failure  | Automatic          | K8s Deployment ReplicaSet replacement + probes    |
| Worker Node Failure      | Automatic          | EKS Managed Node Group auto-scaling replacement   |
| Database Pod Failure     | Automatic          | StatefulSet volume re-attachment on new node      |
| Regional Outage Detect   | Manual / Pipeline  | Human operator or workflow dispatch trigger       |
| DR Workload Deployment   | Manual / Pipeline  | Workflow .github/workflows/dr-drill.yml           |
| Data Snapshot Seeding    | Manual / Pipeline  | API Task/Notes JSON capture & restore in DR       |
| Route 53 Traffic Cutover | Manual / Pipeline  | AWS CLI route53 change-resource-record-sets CNAME |
| Failback to Primary      | Manual / Pipeline  | Workflow operation 'Failback to primary'          |
+--------------------------+--------------------+---------------------------------------------------+
```

---

## 3. Sequence Diagram: Primary EKS Regional Failover

```mermaid
sequenceDiagram
    autonumber
    actor Admin as DR Operator / GitHub Actions
    participant PriEKS as Primary EKS Cluster (Mumbai)
    participant R53 as Route 53 DNS (dr.vaultrix.in)
    participant DREKS as DR EKS Cluster (Singapore)
    participant DRALB as DR AWS Application Load Balancer
    actor User as User Browser

    note over PriEKS: 1. Disaster Declared in Primary Region (ap-south-1)
    
    Admin->>DREKS: 2. Deploy DR Workload (kubectl apply -k kubernetes/overlays/dr)
    DREKS->>DREKS: 3. Launch postgres StatefulSet & notes Deployment Pods
    DREKS->>DRALB: 4. AWS Load Balancer Controller provisions DR ALB in public subnets
    
    loop Poll until Healthy
        Admin->>DRALB: 5. Probe http://<DR_ALB>/healthz with Host: eks.dr.vaultrix.in
        DRALB-->>Admin: HTTP 200 OK
    end

    Admin->>R53: 6. Execute Route 53 CNAME Cutover:<br/>eks-primary.dr.vaultrix.in = <Primary_ALB><br/>eks.dr.vaultrix.in = <DR_ALB>
    R53-->>Admin: Change Set Synced

    User->>R53: 7. DNS Query for eks.dr.vaultrix.in
    R53-->>User: Returns DR ALB CNAME Target
    User->>DRALB: 8. HTTP GET / (User reaches DR EKS Cluster in Singapore!)
```
