# Instructor run-of-show (120 minutes)
| Minutes | Topic | Demo |
|---|---|---|
| 0-15 | Context and architecture | Docker containers vs Kubernetes reconciliation |
| 15-35 | Core concepts | inspect namespace, Deployments, Pods and Services |
| 35-55 | Local cluster | run scripts/local-kind.sh and port-forward |
| 55-70 | Reliability | delete a web Pod; observe replacement; scale to 3 |
| 70-85 | EKS fundamentals | explain control plane, nodes, VPC CNI and ECR |
| 85-100 | AWS workflow | walk through ECR push and EKS deployment (optional live) |
| 100-112 | Observability/security | logs, describe, events, RBAC and HPA |
| 112-120 | Review and discussion | compare local vs AWS; cleanup reminder |

**Preflight:** build images and start local cluster before class. For AWS, prepare a funded account with IAM privileges, quotas and network access. EKS creation often exceeds live-demo time. Prefer a preprovisioned cluster or recorded command walkthrough. AWS resources cost money until deleted.

**Demo commands:** `kubectl get all -n fox-insurance`; `kubectl get pods -n fox-insurance -w`; `kubectl delete pod -n fox-insurance -l app=fox-web`; `kubectl scale deployment/fox-web --replicas=3 -n fox-insurance`; `kubectl logs -n fox-insurance deployment/fox-api`; `kubectl describe deployment fox-api -n fox-insurance`; `kubectl get events -n fox-insurance --sort-by=.lastTimestamp`.

**Discussion:** Why ClusterIP? What happens when a Pod dies? What changes between local and EKS? Why is MongoDB not production-ready in this demo? How does an HPA differ from adding worker nodes?
