# Fox Insurance — Kubernetes + Amazon EKS Training Lab

A **GitHub-ready**, small full-stack orchestration lab for tech leads. The UI is **vanilla HTML/JS**, not React, to keep attention on Kubernetes; Express provides read-only APIs backed by seeded MongoDB. The same standard Kubernetes manifests work on local **kind** and **AWS EKS**. No authentication or real customer data; training use only.

## Architecture
```text
Browser -> localhost:8080 (port-forward) -> fox-web Service -> Nginx Pods
                                                       | /api proxy
                                                       v
                                                  fox-api Service -> Express Pods
                                                                            |
                                                                            v
                                                                       mongo Service -> MongoDB Pod
```
On EKS, use the same port-forward for a secure, inexpensive demo. Production external traffic needs a separately configured Ingress/ALB controller, TLS and network policies.

## Requirements
- Docker Engine/Desktop running; `kind`, `kubectl`, Bash; internet for pulling images.
- Local: roughly 4 GB free RAM recommended.
- AWS optional: AWS CLI v2, `eksctl`, IAM permissions to provision EKS/VPC/EC2/ECR, funded account, quotas, and configured credentials.
- Run scripts from the repository root. Linux/macOS/WSL/Git Bash with compatible tools; scripts use Bash. For Windows, WSL is recommended.

## Path A: local kind cluster (recommended live demo)
```bash
bash scripts/local-kind.sh
kubectl get pods,deployments,services -n fox-insurance
kubectl port-forward -n fox-insurance svc/fox-web 8080:80
```
Open http://localhost:8080; choose Customers, Policies or Claims. Stop port-forward with Ctrl+C.

If using Docker Desktop Kubernetes instead of kind: enable Kubernetes, switch to its context, build images locally, and `kubectl apply -k k8s/local`; ensure the cluster can access local Docker images (this varies by Desktop configuration). kind is the reproducible default.

## Path B: EKS (optional, incurs charges)
**Safety:** AWS EKS, EC2 nodes, networking, storage, NAT gateways and load balancers can incur charges. Confirm region, IAM permissions, quotas and pricing first. Never run EKS creation using an unapproved corporate account. The example below uses a small managed node group and is NOT a hardened production setup.

1. Configure AWS CLI credentials with authorized permissions. Choose a supported EKS Kubernetes version compatible with your region and eksctl; do not hard-code a possibly retired version.
2. Create a cluster (often takes 15–30+ minutes):
```bash
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export EKS_CLUSTER=fox-training
eksctl create cluster --name "$EKS_CLUSTER" --region "$AWS_REGION" --managed --nodegroup-name fox-workers --node-type t3.medium --nodes 2 --nodes-min 2 --nodes-max 3 --with-oidc
aws eks update-kubeconfig --name "$EKS_CLUSTER" --region "$AWS_REGION"
kubectl get nodes
```
3. Build/push both images to ECR and deploy:
```bash
bash scripts/eks-push.sh
bash scripts/eks-deploy.sh
kubectl get pods,svc -n fox-insurance
kubectl port-forward -n fox-insurance svc/fox-web 8080:80
```
4. Open http://localhost:8080. EKS nodes must have ECR pull permissions (standard managed-node roles generally provide them). The MongoDB Pod requires no external access. Verify network connectivity and permissions if Pods remain Pending or ImagePullBackOff.

### AWS cleanup — do not skip
```bash
kubectl delete namespace fox-insurance
# After verifying the cluster name and region:
eksctl delete cluster --name "$EKS_CLUSTER" --region "$AWS_REGION" --wait
# Optional: delete training ECR repos and their images after verifying they are not used:
aws ecr delete-repository --repository-name fox-api --force --region "$AWS_REGION"
aws ecr delete-repository --repository-name fox-web --force --region "$AWS_REGION"
```
Confirm deletion in the AWS Console (CloudFormation, EKS, EC2, VPC, ECR). Review remaining billable resources. Local cleanup: `kind delete cluster --name fox-demo`.

## Inspect and troubleshoot
```bash
kubectl get all -n fox-insurance
kubectl get events -n fox-insurance --sort-by=.metadata.creationTimestamp
kubectl logs deployment/fox-api -n fox-insurance
kubectl describe pod -n fox-insurance -l app=fox-api
kubectl rollout status deployment/fox-api -n fox-insurance
kubectl scale deployment/fox-web --replicas=3 -n fox-insurance
```
Optional HPA: requires metrics-server. `kubectl apply -f k8s/base/hpa-optional.yaml` only after metrics are working; use `kubectl top pods -n fox-insurance` to check. Optional RBAC: `kubectl apply -f k8s/base/rbac-optional.yaml`.

## Repository map
- `apps/api/` Express + MongoDB demo backend, seeded on first connection
- `apps/web/` simple UI + Nginx reverse proxy
- `k8s/base/` portable Deployments, Services, ConfigMap and optional HPA/RBAC
- `k8s/local/` local Kustomize overlay
- `k8s/eks/` ECR image overlay, substituted safely by deployment script
- `scripts/` local and AWS deployment helpers
- `docs/` instructor agenda and student practice labs

## Important limitations
- **MongoDB is intentionally disposable**: `emptyDir` means data is lost when the Pod is recreated. On a multi-node cluster, this is a teaching shortcut, not persistence. Use a managed database such as MongoDB Atlas or a properly configured StatefulSet with PVC, backups, auth and HA in real systems.
- No credentials are required for this demo MongoDB; keep it internal only. Do not expose it publicly.
- The demo does not configure Ingress, TLS, external secrets, pod IAM, network policies, image signing, admission policies or CI/CD. Discuss these as production next steps.
- Use `kubectl config current-context` before applying changes; scripts intentionally require confirmation for EKS.

## Slide alignment
The accompanying 44-page lecture has six sections: Kubernetes in Context, Core Concepts, EKS Fundamentals, Deploying to EKS, Scaling and Observability, and Security and Production Patterns. This repo provides hands-on examples for each; advanced AWS integrations are discussed rather than deployed to keep a two-hour class manageable.
