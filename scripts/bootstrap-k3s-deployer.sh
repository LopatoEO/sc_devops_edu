#!/usr/bin/env bash
set -Eeuo pipefail

namespace="${1:-devops-app}"
output_file="${2:-/tmp/github-actions.kubeconfig}"
service_account="github-actions-deployer"
token_secret="${service_account}-token"
kube_api_server="${KUBE_API_SERVER:-https://127.0.0.1:6443}"

if [[ ! "$namespace" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]]; then
  echo "Invalid Kubernetes namespace: $namespace" >&2
  exit 1
fi

if ! command -v k3s >/dev/null 2>&1; then
  echo "k3s was not found. Run this script on the K3s server as root." >&2
  exit 1
fi

kubectl=(k3s kubectl)

"${kubectl[@]}" create namespace "$namespace" \
  --dry-run=client \
  --output=yaml | "${kubectl[@]}" apply --filename=-

"${kubectl[@]}" apply --filename=- <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${service_account}
  namespace: ${namespace}
---
apiVersion: v1
kind: Secret
metadata:
  name: ${token_secret}
  namespace: ${namespace}
  annotations:
    kubernetes.io/service-account.name: ${service_account}
type: kubernetes.io/service-account-token
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ${service_account}
  namespace: ${namespace}
rules:
  - apiGroups: [""]
    resources: ["configmaps", "secrets", "services", "pods", "persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["apps"]
    resources: ["deployments", "statefulsets"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["autoscaling"]
    resources: ["horizontalpodautoscalers"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${service_account}
  namespace: ${namespace}
subjects:
  - kind: ServiceAccount
    name: ${service_account}
    namespace: ${namespace}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ${service_account}
EOF

token_b64=""
ca_data=""
for _ in {1..15}; do
  token_b64="$("${kubectl[@]}" --namespace "$namespace" get secret "$token_secret" --output='jsonpath={.data.token}')"
  ca_data="$("${kubectl[@]}" --namespace "$namespace" get secret "$token_secret" --output='jsonpath={.data.ca\.crt}')"
  if [[ -n "$token_b64" && -n "$ca_data" ]]; then
    break
  fi
  sleep 1
done

if [[ -z "$token_b64" || -z "$ca_data" ]]; then
  echo "Kubernetes did not populate the service-account token Secret" >&2
  exit 1
fi

token="$(printf '%s' "$token_b64" | base64 --decode)"
umask 077
mkdir -p "$(dirname "$output_file")"

cat > "$output_file" <<EOF
apiVersion: v1
kind: Config
clusters:
  - name: production
    cluster:
      server: ${kube_api_server}
      certificate-authority-data: ${ca_data}
contexts:
  - name: production
    context:
      cluster: production
      namespace: ${namespace}
      user: ${service_account}
current-context: production
users:
  - name: ${service_account}
    user:
      token: ${token}
EOF

chmod 600 "$output_file"
echo "Scoped kubeconfig created: $output_file"
echo "Keep this file secret. The credential can deploy only inside namespace: $namespace"

