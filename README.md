# Aire - AI Runtime Environment

GitOps repository for a local Kubernetes cluster running **agentgateway** and **kagent**
with Google Gemini as the LLM provider, managed by **Flux CD**.

## Prerequisites

| Tool | Install |
|------|---------|
| Docker | <https://docs.docker.com/get-docker/> |
| kind | `brew install kind` |
| kubectl | `brew install kubectl` |
| flux | `brew install fluxcd/tap/flux` |
| GitHub PAT | `export GITHUB_TOKEN=<token>` (repo scope) |

## Quick Start

```bash
# 1. Set required environment variables
export GITHUB_TOKEN=<your-github-pat>
export GEMINI_API_KEY=<your-gemini-api-key>

# 2. Create cluster, secrets, and bootstrap Flux (all-in-one)
make all

# 3. Check status
make status
```

## Step-by-Step

```bash
# Create the kind cluster
make cluster-create

# Install Gateway API CRDs (cluster prerequisite)
make gateway-api-crds

# Create secrets (requires GEMINI_API_KEY env var)
make secrets

# Bootstrap Flux (requires GITHUB_TOKEN env var)
make flux-bootstrap
```

## Architecture

```
Kagent Agent
    |
    v (ModelConfig baseUrl)
AgentGateway Proxy  (Gateway + HTTPRoute)
    |
    v (AgentgatewayBackend + Secret)
Google Gemini API
```

Flux reconciles the repository and deploys:

1. **Gateway API CRDs** (v1.5.0)
2. **AgentGateway** via Helm (CRDs + control plane)
3. **Kagent** via Helm (CRDs + controller)
4. Kubernetes-native resources: Gateway, AgentgatewayBackend, HTTPRoute, ModelConfig, Agent

## Repository Layout

```
clusters/local/          Flux entry point (Kustomizations)
infrastructure/
  sources/               HelmRepository definitions (OCI)
  gateway-api/           Gateway API CRDs
  agentgateway/          AgentGateway Helm releases + Gemini config
  kagent/                Kagent Helm releases + ModelConfig + Agent
apps/                    Application workloads (placeholder)
scripts/                 Helper scripts (kind config, secret creation)
```

## Secrets

API keys are **never** committed to Git. The placeholder Secret manifests in
`infrastructure/agentgateway/` and `infrastructure/kagent/` contain `REPLACE_ME`
values. Use `make secrets` (or `scripts/create-secrets.sh`) to create real
secrets from the `GEMINI_API_KEY` environment variable.

For production, consider [Mozilla SOPS](https://fluxcd.io/flux/guides/mozilla-sops/)
or [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets).

## Cleanup

```bash
make clean
```
