# Aire - AI Runtime Environment

GitOps repository for a local Kubernetes cluster running **agentgateway** and **kagent**
with Google Gemini as the LLM provider, managed by **Flux CD**.

## Prerequisites

| Tool | macOS | Ubuntu |
|------|-------|--------|
| Docker | <https://docs.docker.com/get-docker/> | `sudo apt-get install docker.io` |
| kind | `brew install kind` | `go install sigs.k8s.io/kind@latest` |
| kubectl | `brew install kubectl` | [install guide](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/) |
| flux | `brew install fluxcd/tap/flux` | `curl -s https://fluxcd.io/install.sh \| bash` |
| Go (1.22+) | `brew install go` | `sudo snap install go --classic` |
| GitHub PAT | `export GITHUB_TOKEN=<token>` (repo scope) | same |

`cloud-provider-kind` is auto-installed by `make cloud-provider` via `go install` if not already present.

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

# Start cloud-provider-kind for LoadBalancer support (auto-installs if missing)
make cloud-provider

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
clusters/local/
  infra-sources.yaml       Flux Kustomization -> infrastructure/sources/
  infra-controllers.yaml   Flux Kustomization -> infrastructure/controllers/ (depends on sources)
  infra-config.yaml        Flux Kustomization -> infrastructure/config/ (depends on controllers)
  apps.yaml                Flux Kustomization -> apps/ (depends on config)
infrastructure/
  sources/                 HelmRepository definitions (OCI)
  controllers/             Namespaces + HelmReleases (agentgateway, kagent)
  config/                  CRD-based resources (Gateway, Backend, Route, ModelConfig, Agent)
apps/                      Application workloads (placeholder)
scripts/                   Helper scripts (kind config, secret creation)
```

Flux reconciles layers in order: **sources -> controllers -> config -> apps**.
This ensures CRDs from HelmReleases are installed before custom resources
(like `AgentgatewayBackend`) are applied.

## Secrets

API keys are **never** committed to Git. The placeholder Secret manifests in
`infrastructure/config/` contain `REPLACE_ME` values.
Use `make secrets` (or `scripts/create-secrets.sh`) to create real
secrets from the `GEMINI_API_KEY` environment variable.

For production, consider [Mozilla SOPS](https://fluxcd.io/flux/guides/mozilla-sops/)
or [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets).

## Cleanup

```bash
make clean
```
