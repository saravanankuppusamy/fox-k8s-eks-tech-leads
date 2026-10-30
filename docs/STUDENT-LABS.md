# Student practice labs
## Lab 1: inspect local cluster (15 minutes)
Run local setup from README. Use `kubectl get nodes`, `kubectl get deployments,pods,svc -n fox-insurance`, and `kubectl describe deployment fox-api -n fox-insurance`. Identify the desired and actual replica counts.

## Lab 2: service discovery (10 minutes)
Start `kubectl port-forward -n fox-insurance svc/fox-web 8080:80` and browse http://localhost:8080. Click Customers, Policies and Claims. Explain why the browser uses `/api` and Nginx uses `fox-api:3000`.

## Lab 3: self-healing (10 minutes)
Run `kubectl delete pod -n fox-insurance -l app=fox-web`, then `kubectl get pods -n fox-insurance -w`. Explain the new Pod.

## Lab 4: scale and rolling update (15 minutes)
`kubectl scale deployment/fox-api -n fox-insurance --replicas=3`; `kubectl get pods -n fox-insurance`. For a rollout demonstration, rebuild and load an image with a distinct tag and update the Deployment image; inspect `kubectl rollout history deployment/fox-api -n fox-insurance`. Avoid overwriting a tag during a rollout.

## Lab 5: EKS review (optional; AWS charges apply)
Follow README AWS instructions. Compare `kubectl get nodes` on local and EKS. Use ECR images and inspect the same workloads. Do not leave the EKS cluster running.

## Lab 6: optional HPA and RBAC (15 minutes)
Apply `kubectl apply -f k8s/base/rbac-optional.yaml`. Run `kubectl auth can-i list pods -n fox-insurance --as=system:serviceaccount:fox-insurance:fox-observer`. HPA requires a working metrics-server: after installing it, apply `k8s/base/hpa-optional.yaml`, inspect `kubectl get hpa -n fox-insurance`. A low-load demo may not trigger scaling.

## Questions and sample answers
1. Pod vs Deployment? A Pod runs containers; a Deployment maintains desired replica count and handles updates.
2. Why a Service? Stable DNS/network access despite changing Pod IPs.
3. What does readiness do? Removes unhealthy Pods from Service endpoints.
4. ECR vs EKS? ECR stores images; EKS runs Kubernetes workloads.
5. What is portable? Standard manifests and kubectl concepts; AWS IAM/VPC integrations are not.
6. Why requests/limits? Scheduling, resource protection and autoscaling calculations.
7. Why not use this MongoDB deployment in production? It uses ephemeral storage, no authentication, no backups, and no HA.
