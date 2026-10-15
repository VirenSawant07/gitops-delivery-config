# gitops-delivery-config

[![validate](https://github.com/VirenSawant07/gitops-delivery-config/actions/workflows/validate.yaml/badge.svg)](https://github.com/VirenSawant07/gitops-delivery-config/actions/workflows/validate.yaml)

The **desired state** of the GitOps Delivery Platform. ArgoCD keeps the Kind cluster identical to this repo.
Application code and the full project overview: **[gitops-delivery-app](https://github.com/VirenSawant07/gitops-delivery-app)**.

## Layout

```
bootstrap/
  kind-config.yaml        3-node Kind cluster (1 control plane, 2 workers)
  argocd-values.yaml      minimal ArgoCD settings (60 s Git polling)
  bootstrap.sh            one command: cluster → ArgoCD → root app
argocd/
  root.yaml               app-of-apps (the only manifest applied by hand)
  apps/
    workloads.yaml        ApplicationSet: one Application per apps/<env>/<service>.yaml
    monitoring.yaml       kube-prometheus-stack (chart repo + values from this repo)
    sealed-secrets.yaml   Sealed Secrets controller
    observability.yaml    everything in observability/
charts/service/           one reusable chart: Deployment, Service, PDB, NetworkPolicy, ServiceMonitor
apps/
  staging/                values per service, image tag updated by app CI
  prod/                   values per service, changed only by a merged promote PR
platform/monitoring/      kube-prometheus-stack values (Kind tweaks, Discord routing)
observability/            alert rules, Grafana dashboard, SealedSecrets, synthetic traffic
.github/workflows/
  validate.yaml           helm lint + render + kubeconform on every push
  promote.yaml            manual: copy staging tags to prod and open a PR
```

## How changes flow

| Change | Who makes it | Path to the cluster |
|---|---|---|
| New image in staging | app CI (deploy key) | commit to `apps/staging/` → ArgoCD sync |
| Release to prod | a human | **promote** workflow → PR → review → merge → ArgoCD sync |
| Rollback | a human | `git revert <deploy commit>` → ArgoCD sync |
| Platform or chart change | a human | branch → PR (validated) → merge → ArgoCD sync |

ArgoCD runs with automated sync, **prune** (delete what was removed from Git) and **self-heal** (undo manual changes).

## Validation

Every push to every branch runs `validate`:
1. `helm lint --strict` for every service × environment
2. `helm template` to render the final manifests
3. `kubeconform -strict` against Kubernetes schemas and CRD schemas (ArgoCD, Prometheus Operator, Sealed Secrets)

Typos, wrong API versions and invalid fields are caught before merge, not at deploy time.

## Alerts

Defined in [`observability/alerts.yaml`](observability/alerts.yaml) and routed to Discord. Each alert links to a runbook in the app repo.

| Alert | Fires when |
|---|---|
| HighErrorRate | > 5% of requests return 5xx for 1 min |
| ServiceDown | no healthy scrape targets for 1 min |
| PodRestartingFrequently | ≥ 2 restarts in 10 min |
| HighCPUUsage | > 80% of the CPU limit for 5 min |
| HighMemoryUsage | > 85% of the memory limit for 5 min |

## Secrets

`observability/sealed-*.yaml` are SealedSecrets, encrypted with the cluster's public key. Only the in-cluster controller can decrypt them. To re-seal on a new cluster:

```bash
kubectl create secret generic alertmanager-discord -n monitoring \
  --from-file=webhook-url=./discord-webhook.txt --dry-run=client -o yaml \
  | kubeseal --controller-name sealed-secrets-controller --controller-namespace kube-system --format yaml \
  > observability/sealed-alertmanager-discord.yaml
```
