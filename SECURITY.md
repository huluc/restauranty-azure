# Security

This document describes the security controls of the Restauranty on Azure project, what was found during the project, and the limitations I accepted on purpose. It is a portfolio project: two AKS clusters (staging and production) that are created every morning and deleted every evening.

## Principles

1. **No long-lived secrets in Git, images, charts or pipeline settings.** Secrets live in Azure Key Vault.
2. **Identities instead of passwords.** Workloads and the pipeline sign in to Azure with workload identity federation (Entra ID trusts a token issued by AKS or Azure DevOps).
3. **Least privilege.** Every identity gets only the roles it needs, on the smallest scope.
4. **Gates in the pipeline.** Secrets, code and images are scanned before anything is deployed.
5. **Git is the source of truth.** Clusters are changed through Git and Argo CD; manual changes are reverted.

## Controls by layer

### Identity and access

| Identity | Used by | Roles (scope) |
| --- | --- | --- |
| Service connection `azure-restauranty` (app registration, workload identity federation) | Azure Pipelines | `AcrPush` + `Reader` (ACR), `Key Vault Secrets User` (only the secret `github-gitops-token`) |
| `id-hilal-restauranty-eso` (user-assigned managed identity) | External Secrets Operator in both clusters | `Key Vault Secrets User` (Key Vault). Federated credentials trust only `system:serviceaccount:external-secrets:external-secrets` from each cluster's OIDC issuer |
| AKS kubelet identities | Nodes | `AcrPull` (ACR) |
| My user account | Terraform, Azure CLI | `Key Vault Secrets Officer` (Key Vault), `Storage Blob Data Contributor` (Terraform state) |

The pipeline identity was created with `Contributor` on the whole resource group by Azure DevOps ("automatic" service connection). With that role it could have deleted the clusters or read their admin credentials, which a GitOps pipeline never needs. I replaced it with the roles above and verified that the pipeline still builds, pushes and updates Git.

### Secrets

- Application secrets (MongoDB credentials, JWT signing key, Cloudinary keys, Grafana admin password) and the GitHub token for the pipeline are stored in **Azure Key Vault** (RBAC mode, soft delete).
- **External Secrets Operator** creates Kubernetes Secrets from Key Vault. The `MONGODB_URI` is assembled inside the cluster from the username and password, so it never exists outside.
- Random secrets were generated with `openssl rand` and written to Key Vault without being printed (`-o none`, `read -s`). Values were verified only by length and prefix.
- The GitHub token is **fine-grained**: one repository, `Contents: read and write`, 30-day expiry.
- `.env` files and `terraform.tfvars` are excluded by `.gitignore`. The Grafana chart default password is not used.

### Pipeline and supply chain

| Gate | Tool | Blocks on |
| --- | --- | --- |
| Secrets in Git history | gitleaks 8.30.1 (full history, `fetchDepth: 0`) | Any new finding |
| Static code analysis | Semgrep 1.185.0 (JavaScript, Node.js, React rule sets) | Any finding |
| Image vulnerabilities | Trivy 0.76.2 | CRITICAL vulnerabilities with an available fix |
| Production deployment | Azure DevOps environment approval | Missing manual approval |

- Tool, chart and image versions are **pinned** (no `latest`); build agents are pinned to `ubuntu-24.04`.
- Images are tagged with the commit SHA and **built once**; staging and production run the same image.
- The approval check is defined on the `production` environment, not in the pipeline file, so editing the YAML cannot skip it.
- The pipeline has no access to the clusters. It only pushes images and commits image tags; Argo CD deploys.

### Containers

- Multi-stage builds, minimal Alpine-based images, OS packages upgraded at build time.
- Non-root numeric users (`1000` for the Node.js services, `101` for the client), `runAsNonRoot`.
- `readOnlyRootFilesystem: true` with an `emptyDir` for `/tmp`, `allowPrivilegeEscalation: false`, all Linux capabilities dropped, `seccompProfile: RuntimeDefault`.
- CPU and memory requests, memory limits.

### Kubernetes and network

- **NetworkPolicies** (enforced by Cilium) in the `restauranty` namespace: default deny for ingress; internet → gateway (port 80); gateway → the four services (named port `http`); auth/discounts/items → MongoDB (27017); in production also Prometheus → backends. Verified: `auth` reaches MongoDB, `client` times out.
- Only the gateway's Azure Load Balancer is public (port 80). Everything else is `ClusterIP`.
- Pod Security Admission labels `warn` and `audit` at the `restricted` level.
- Production system node pool is tainted (`CriticalAddonsOnly`), so application pods run on the user pool.
- Argo CD self-heal reverts manual changes to managed resources.

### Infrastructure

- Terraform state in Azure Storage: public access off, shared keys off, Entra ID auth, versioning on, TLS 1.2.
- ACR admin user disabled; nodes pull with their managed identity.
- Container logs and pod inventory go to Log Analytics (30 days), outside the clusters.
- Budget alert at 150 EUR per month.

## Findings during the project

| Finding | How it was found | Outcome |
| --- | --- | --- |
| CVE-2026-111497 (CRITICAL) in `brotli-libs` of the client base image | Trivy stopped the pipeline | Fixed with `apk upgrade` in the runtime stage; tracked as a work item and closed |
| Cloudinary API secret committed in upstream history (commit `6b07897`, original author, April 2025, three `cloudinary.config.js` files) | gitleaks history scan | The current code reads the value from environment variables. The key belongs to a third-party account and **cannot be rotated by me**; it should be reported to the upstream owner. The three fingerprints are listed in `.gitleaksignore` so that only new leaks fail the pipeline |
| Pipeline identity had `Contributor` on the resource group | Review of role assignments | Reduced to `AcrPush` + `Reader` on ACR |
| Container Insights agent sent no data | Empty Log Analytics workspace | The data collection rule was missing (Terraform does not create it like the portal does); added a DCR and association per cluster |

## Known limitations (accepted for this project)

| Limitation | Risk | What I would do in production |
| --- | --- | --- |
| HTTP only, no TLS on the gateway | Traffic and JWTs are readable in transit | cert-manager with Let's Encrypt and an HTTPS listener |
| Changes in `charts/`, `k8s/` and `argocd/` reach both clusters without approval | A bad config change hits production directly | Branch protection with pull request reviews, environment-specific Git paths |
| Argo CD runs in production and its `argocd-manager` account is cluster-admin on staging | Production compromise also exposes staging | Dedicated management cluster, narrower RBAC for the Argo CD service account |
| Argo CD uses the local `admin` account | No central identity or audit for Argo CD logins | Entra ID SSO (OIDC), local admin disabled |
| Egress is not restricted | A compromised pod can call any external host | Egress NetworkPolicies (DNS, Key Vault, Cloudinary only) |
| Pod Security Admission only warns | Non-compliant pods are not rejected | Switch to `enforce: restricted` |
| MongoDB has no backups and a single replica | Data loss, zone dependency | Replica set or managed database, scheduled backups |
| Key Vault purge protection is off | Deleted secrets can be purged | Turn it on (it is off so the project can be torn down cleanly) |
| Prometheus has no authentication outside port-forward and no persistent storage | History is lost on restart | Persistent volumes or managed Prometheus, access through SSO |
| Microsoft Defender for Cloud is not enabled | No runtime threat detection | Enable Defender for Containers |

## Reporting a vulnerability

Please open a private security advisory on this GitHub repository (Security → Advisories) instead of a public issue.
