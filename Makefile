CLUSTER_NAME   := aire
GITHUB_OWNER   := sfesfizh
GITHUB_REPO    := aire
BRANCH         := main
FLUX_PATH      := clusters/local

.PHONY: all cluster-create cluster-delete gateway-api-crds cloud-provider flux-bootstrap secrets status clean

all: cluster-create gateway-api-crds cloud-provider secrets flux-bootstrap

# --- Kind cluster -----------------------------------------------------------

cluster-create:
	@echo "==> Creating kind cluster '$(CLUSTER_NAME)'..."
	kind create cluster --config scripts/kind-config.yaml --wait 60s
	@echo "==> Removing LB exclusion label from control-plane node..."
	kubectl label node $(CLUSTER_NAME)-control-plane node.kubernetes.io/exclude-from-external-load-balancers- || true
	@echo "==> Cluster ready."

cluster-delete:
	kind delete cluster --name $(CLUSTER_NAME)

# --- Cloud Provider Kind (LoadBalancer support) ------------------------------

cloud-provider:
	@echo "==> Starting cloud-provider-kind as a container..."
	@if docker ps --format '{{.Names}}' | grep -q '^cloud-provider-kind$$'; then \
		echo "    cloud-provider-kind container is already running."; \
	else \
		docker run -d --rm \
			--name cloud-provider-kind \
			--network kind \
			-v /var/run/docker.sock:/var/run/docker.sock \
			registry.k8s.io/cloud-provider-kind/cloud-controller-manager:v0.6.0 ; \
		echo "    Container started. Logs: docker logs -f cloud-provider-kind"; \
	fi

# --- Gateway API CRDs --------------------------------------------------------

gateway-api-crds:
	@echo "==> Installing Gateway API v1.5.0 CRDs..."
	kubectl apply --server-side -f \
		https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml
	@echo "==> Gateway API CRDs installed."

# --- Secrets -----------------------------------------------------------------

secrets:
	@echo "==> Creating Kubernetes secrets..."
	bash scripts/create-secrets.sh

# --- Flux --------------------------------------------------------------------

flux-bootstrap:
	@echo "==> Bootstrapping Flux from GitHub..."
	flux bootstrap github \
		--owner=$(GITHUB_OWNER) \
		--repository=$(GITHUB_REPO) \
		--branch=$(BRANCH) \
		--path=$(FLUX_PATH) \
		--personal \
		--token-auth
	@echo "==> Flux bootstrap complete."

# --- Status ------------------------------------------------------------------

status:
	@echo "==> Flux Kustomizations"
	@flux get kustomizations
	@echo ""
	@echo "==> Flux HelmReleases"
	@flux get helmreleases -A
	@echo ""
	@echo "==> Pods (all namespaces)"
	@kubectl get pods -A

# --- Cleanup -----------------------------------------------------------------

clean: cluster-delete
