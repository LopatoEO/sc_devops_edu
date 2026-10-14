#!/usr/bin/env bash
set -Eeuo pipefail
: "${KUBE_CONFIG:?Set KUBE_CONFIG as a GitLab File variable}"
: "${REGISTRY_PULL_USER:?Set a long-lived registry deploy-token username}"
: "${REGISTRY_PULL_PASSWORD:?Set a deploy token with read_registry}"
export KUBECONFIG="$KUBE_CONFIG"
kubectl config current-context
kubectl get nodes
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NAMESPACE" create secret docker-registry registry-pull \
  --docker-server="$CI_REGISTRY" --docker-username="$REGISTRY_PULL_USER" \
  --docker-password="$REGISTRY_PULL_PASSWORD" --dry-run=client -o yaml | kubectl apply -f -
if [[ -n "$(kubectl -n "$NAMESPACE" get secret postgres-auth --ignore-not-found -o name)" ]]; then
  present=$(kubectl -n "$NAMESPACE" get secret postgres-auth -o go-template='{{if index .data "POSTGRES_PASSWORD"}}yes{{end}}')
  [[ "$present" == yes ]] || { echo 'postgres-auth is missing POSTGRES_PASSWORD'; exit 1; }
else
  : "${POSTGRES_PASSWORD:?Set POSTGRES_PASSWORD for the first deployment}"
  kubectl -n "$NAMESPACE" create secret generic postgres-auth --from-literal=POSTGRES_PASSWORD="$POSTGRES_PASSWORD"
fi
