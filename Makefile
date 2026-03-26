CLUSTER_NAME   := aire
GITHUB_OWNER   := sfesfizh
GITHUB_REPO    := aire
BRANCH         := main
FLUX_PATH      := clusters/local

.PHONY: all cluster-create cluster-delete cloud-provider flux-bootstrap secrets status clean check-env

all: check-env cluster-create cloud-provider secrets flux-bootstrap

# --- Environment checks ------------------------------------------------------

check-env:
ifndef GEMINI_API_KEY
	$(error GEMINI_API_KEY is not set. Export it first: export GEMINI_API_KEY=<your-key>)
endif

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
	@echo "==> Setting up cloud-provider-kind..."
	@if ! command -v cloud-provider-kind > /dev/null 2>&1; then \
		echo "    Installing cloud-provider-kind via go install..."; \
		go install sigs.k8s.io/cloud-provider-kind@latest; \
	fi
	@if pgrep -x cloud-provider-kind > /dev/null 2>&1; then \
		echo "    cloud-provider-kind is already running."; \
	else \
		nohup cloud-provider-kind > /tmp/cloud-provider-kind.log 2>&1 & \
		sleep 2; \
		echo "    Started.  Logs: /tmp/cloud-provider-kind.log"; \
	fi

# --- Gateway API CRDs --------------------------------------------------------

# gateway-api-crds:
# 	@echo "==> Installing Gateway API v1.5.0 CRDs..."
# 	kubectl apply --server-side -f \
# 		https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml
# 	@echo "==> Gateway API CRDs installed."

# --- Secrets -----------------------------------------------------------------

secrets: check-env
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
