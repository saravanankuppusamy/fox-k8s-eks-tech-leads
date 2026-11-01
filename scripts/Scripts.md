# Fox Insurance — Kubernetes & Amazon EKS Script Execution Guide

**Audience:** Tech leads working with developers  
**Purpose:** Understand the execution flow of the three scripts in `scripts/` without needing to master Bash.  
**Run location:** Repository root (`fox-k8s-eks/`).

## 1. Big picture: Build → Publish → Deploy → Verify

```text
                         Fox Insurance source code
                        apps/api/       apps/web/
                             |              |
             +---------------+--------------+---------------+
             |                                              |
      LOCAL KUBERNETES                               AWS EKS WORKFLOW
             |                                              |
     scripts/local-kind.sh                           scripts/eks-push.sh
       - create/reuse kind                              - AWS ECR login
       - build Docker images                            - create ECR repos if needed
       - load images into kind                          - build/tag/push images
       - apply K8s manifests                                    |
       - check rollouts                                 Amazon ECR registry
             |                                                  |
       Local kind cluster                              scripts/eks-deploy.sh
       MongoDB + API + Web                               - select EKS context
             |                                           - confirm destination
      localhost:8080                                     - apply K8s manifests
                                                         - check rollouts
                                                                |
                                                          AWS EKS cluster
                                                          MongoDB + API + Web
```

**Key distinction:** `local-kind.sh` builds and deploys locally; `eks-push.sh` publishes images to ECR but does **not** deploy them; `eks-deploy.sh` deploys previously published images to an **existing** EKS cluster.

## 2. `scripts/local-kind.sh` — Local Kubernetes setup and deployment

**Purpose:** Build and run Fox Insurance on a local `kind` (Kubernetes in Docker) cluster.

| Step | What the script does | Why it matters |
|---|---|---|
| 1 | Runs with `set -euo pipefail` | Stops on command errors, unset variables and pipeline failures. |
| 2 | Checks for a kind cluster named `fox-demo`; creates it if absent | Provides a local Kubernetes environment without AWS. |
| 3 | Selects context `kind-fox-demo` | Directs subsequent `kubectl` operations to the intended cluster. |
| 4 | Builds Docker images `fox-api:demo` and `fox-web:demo` | Packages the API and web application as container images. |
| 5 | Loads both images into kind | Makes locally built images available to the cluster without ECR. |
| 6 | Runs `kubectl apply -k k8s/local` | Applies the Kustomize configuration, including namespace, configuration, MongoDB, API and web resources. |
| 7 | Waits for MongoDB, API and web Deployment rollouts (180 seconds each) | Checks that Kubernetes reports each Deployment rollout complete. |
| 8 | Prints the port-forward command | Shows how to access the web application from the instructor's machine. |

**Run and verify:**

```bash
bash scripts/local-kind.sh
kubectl get deployments,pods,services -n fox-insurance
kubectl port-forward -n fox-insurance svc/fox-web 8080:80
```

Open **http://localhost:8080** while port-forward is running. Port-forward runs in the foreground; use another terminal for other commands.

**Teaching point:** Docker builds images; kind provides the local cluster; `kubectl` submits the desired configuration; Kubernetes schedules and maintains the Pods.

## 3. `scripts/eks-push.sh` — Publish container images to Amazon ECR

**Purpose:** Make the Fox Insurance web and API images available for AWS EKS to pull.

| Step | What the script does | Why it matters |
|---|---|---|
| 1 | Requires `AWS_REGION` and `AWS_ACCOUNT_ID` | Identifies the target AWS registry. |
| 2 | Constructs `<account>.dkr.ecr.<region>.amazonaws.com` | Defines the ECR registry address. |
| 3 | Uses AWS CLI credentials to log Docker into ECR | Authorizes image pushes. |
| 4 | Checks for ECR repositories `fox-api` and `fox-web`; creates missing ones with scan-on-push enabled | Provides destinations for the two images. |
| 5 | Builds `fox-api:demo` and `fox-web:demo` | Packages the source code. |
| 6 | Tags each image with its full ECR repository address and `demo` tag | Gives each image a registry-qualified name. |
| 7 | Pushes both images to ECR | Makes the images available for EKS nodes to retrieve. |
| 8 | Prints the registry location | Helps confirm where images were published. |

**Run:**

```bash
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=YOUR_AWS_ACCOUNT_ID
bash scripts/eks-push.sh
```

**Teaching point:** ECR is an **image registry**, not a running application or Kubernetes cluster. This script does not create an EKS cluster or Kubernetes Pods.

**Important lab note:** The script reuses the mutable `demo` tag. For production, use unique immutable version or commit tags and a controlled deployment process.

## 4. `scripts/eks-deploy.sh` — Deploy Fox Insurance to Amazon EKS

**Purpose:** Apply Kubernetes configuration to an already-created, accessible EKS cluster using images previously pushed to ECR.

| Step | What the script does | Why it matters |
|---|---|---|
| 1 | Requires `AWS_REGION` and `AWS_ACCOUNT_ID`; defaults `EKS_CLUSTER` to `fox-training` | Identifies AWS account, region and target cluster. |
| 2 | Runs `aws eks update-kubeconfig` | Configures local `kubectl` authentication/context for EKS. |
| 3 | Displays the current context and prompts for the exact word `yes` | Reduces the risk of deploying to the wrong cluster. |
| 4 | Creates a temporary directory and copies `k8s/eks` and `k8s/base` | Prepares an isolated copy of the manifests without editing repository files. |
| 5 | Replaces `REPLACE_ACCOUNT` and `REPLACE_REGION` in the copied EKS Kustomization | Points the deployments at the correct ECR images. |
| 6 | Runs `kubectl apply -k` on the temporary EKS directory | Creates or updates the namespace, configuration and workloads in EKS. |
| 7 | Waits for API and web rollouts (240 seconds each) | Checks that the two application Deployments report successful rollout. |
| 8 | Removes temporary files on exit | Leaves the repository manifests unchanged. |

**Run and verify:**

```bash
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=YOUR_AWS_ACCOUNT_ID
export EKS_CLUSTER=fox-training
bash scripts/eks-deploy.sh
kubectl get deployments,pods,services -n fox-insurance
kubectl get events -n fox-insurance --sort-by=.metadata.creationTimestamp
```

**Prerequisites:** An EKS cluster already exists, the AWS identity has sufficient permissions, worker capacity is available, ECR images have been pushed, and EKS nodes can pull them. **This script does not create the cluster, configure a public load balancer, or install the AWS Load Balancer Controller.** The base manifests also deploy a classroom MongoDB instance; this is not a production database architecture.

**Teaching point:** The Kubernetes resources are largely portable. EKS-specific details here are cluster access and ECR image references.

## 5. Side-by-side comparison

| Activity | `local-kind.sh` | `eks-push.sh` | `eks-deploy.sh` |
|---|---|---|---|
| Create local kind cluster if missing | Yes | No | No |
| Create EKS cluster | No | No | No |
| Build API/web Docker images | Yes | Yes | No |
| Load images into local kind | Yes | No | No |
| Create ECR repositories if needed | No | Yes | No |
| Push images to ECR | No | Yes | No |
| Apply Kubernetes manifests | Yes | No | Yes |
| Check application rollouts | Yes (MongoDB, API, web) | No | Yes (API, web) |
| Main tools | Docker, kind, kubectl | AWS CLI, Docker | AWS CLI, kubectl |

## 6. Five essential concepts for tech leads

1. **Container image vs. running Pod:** Docker builds the packaged application; Kubernetes runs and manages it.
2. **Registry vs. cluster:** ECR stores images; EKS runs Kubernetes workloads.
3. **Desired state:** Manifests describe what should exist; Kubernetes controllers reconcile the actual state toward it.
4. **Portability:** Deployments, Services and ConfigMaps are Kubernetes resources; ECR paths and AWS networking are environment-specific.
5. **Deployment verification:** A successful `kubectl apply` only means the request was accepted. Use rollout status, Pod readiness, logs and events to diagnose application health.

## 7. Instructor walkthrough and student practice

**Suggested walkthrough:** Run the local script; inspect Pods and Services; access the app; delete an API Pod and watch its Deployment replace it; explain how the same images are published to ECR and applied to EKS.

```bash
# Inspect application resources
kubectl get pods -n fox-insurance -o wide
kubectl get deployments -n fox-insurance
kubectl get services -n fox-insurance

# Observe reconciliation: delete one API Pod (Kubernetes recreates it)
kubectl get pods -n fox-insurance -l app=fox-api
# Substitute an actual API Pod name from the command above:
kubectl delete pod POD_NAME -n fox-insurance
kubectl get pods -n fox-insurance -w

# Troubleshooting
kubectl describe deployment fox-api -n fox-insurance
kubectl logs deployment/fox-api -n fox-insurance --tail=50
kubectl get events -n fox-insurance --sort-by=.metadata.creationTimestamp
```

If the API Pod selector differs in a modified repository, inspect `kubectl get pods --show-labels -n fox-insurance` first. Press **Ctrl+C** to stop the watch.

**Review question:** What happens if one Fox Insurance API Pod crashes or is deleted?  
**Sample answer:** Kubernetes controllers attempt to restore the desired number of Pods. Readiness checks help ensure traffic is directed to Pods that are ready. Replacement depends on available cluster resources and valid configuration.

**Review question:** Why are there two AWS scripts?  
**Sample answer:** Building and publishing images to ECR is a separate responsibility from applying workload definitions to EKS. This separation helps teams manage release and deployment steps independently.

**Review question:** What changes between local kind and EKS?  
**Sample answer:** The cluster context and image distribution mechanism change. Many Kubernetes resource definitions remain the same, while AWS-specific registry, networking, permissions and infrastructure details must be configured.

## 8. Operational cautions

- Always verify the active context before running commands that change a cluster: `kubectl config current-context`.
- EKS and associated AWS resources can incur charges even when no students are using them. Follow your organization's cluster and resource cleanup procedures after the lab.
- The classroom MongoDB deployment is not a recommended production data-storage design; consider a managed database and persistent, backed-up storage for real workloads.
- A rollout succeeding does not guarantee all end-to-end features work; validate the application in the browser and check API behavior.
- These instructions explain the supplied scripts as written; they do not claim that an EKS deployment was executed or tested.

---

*Fox Insurance Kubernetes / Amazon EKS — student repository reference guide.*
