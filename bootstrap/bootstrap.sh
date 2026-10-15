#!/usr/bin/env bash
# Rebuilds the whole platform from Git: Kind cluster -> ArgoCD -> root app.
# Everything else (workloads, monitoring) is then installed by ArgoCD from this repo.
set -euo pipefail
cd "$(dirname "$0")/.."

ARGOCD_CHART_VERSION=10.10.5

if ! kind get clusters | grep -qx gitops; then
  kind create cluster --config bootstrap/kind-config.yaml
fi

helm upgrade --install argocd argo-cd \
  --repo https://argoproj.github.io/argo-helm --version "$ARGOCD_CHART_VERSION" \
  --namespace argocd --create-namespace \
  --values bootstrap/argocd-values.yaml --wait

kubectl apply -f argocd/root.yaml

echo
echo "ArgoCD is up. UI:  kubectl -n argocd port-forward svc/argocd-server 8443:443  ->  https://localhost:8443"
echo "Login: admin / $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
