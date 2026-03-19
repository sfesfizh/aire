#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${GEMINI_API_KEY:-}" ]]; then
  echo "Error: GEMINI_API_KEY environment variable is not set."
  echo "Usage: export GEMINI_API_KEY=<your-key> && $0"
  exit 1
fi

echo "Creating Gemini secret in agentgateway-system namespace..."
kubectl create namespace agentgateway-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic google-secret \
  --namespace agentgateway-system \
  --from-literal=Authorization="${GEMINI_API_KEY}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Creating Gemini secret in kagent namespace..."
kubectl create namespace kagent --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic kagent-gemini \
  --namespace kagent \
  --from-literal=GOOGLE_API_KEY="${GEMINI_API_KEY}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secrets created successfully."
