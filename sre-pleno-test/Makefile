# Makefile para SRE Pleno Test - Online Boutique
# Autor: Pablo Shizato (pabloshizato@gmail.com)
# Data: Janeiro 2026

.PHONY: help setup deploy deploy-app deploy-observability clean test status logs port-forward-grafana port-forward-kibana port-forward-app

# Variáveis
CLUSTER_NAME := sre-pleno
NAMESPACE := online-boutique
MONITORING_NS := monitoring
LOGGING_NS := logging

# Cores
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m

##@ Comandos Principais

help: ## Mostra esta mensagem de ajuda
	@echo "$(BLUE)SRE Pleno Test - Online Boutique$(NC)"
	@echo ""
	@echo "$(GREEN)Comandos disponíveis:$(NC)"
	@awk 'BEGIN {FS = ":.*##"; printf "\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(BLUE)%-20s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(YELLOW)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

setup: ## Provisiona cluster Kind e instala dependências
	@echo "$(GREEN)Provisionando cluster Kubernetes...$(NC)"
	./scripts/setup-cluster.sh

deploy: deploy-app deploy-observability ## Deploy completo (aplicação + observabilidade)

deploy-app: ## Deploy apenas da aplicação Online Boutique
	@echo "$(GREEN)Fazendo deploy da aplicação...$(NC)"
	./scripts/deploy-app.sh

deploy-observability: ## Deploy apenas do stack de observabilidade
	@echo "$(GREEN)Fazendo deploy do stack de observabilidade...$(NC)"
	./scripts/deploy-observability.sh

clean: ## Remove todos os recursos e deleta o cluster
	@echo "$(YELLOW)Limpando ambiente...$(NC)"
	./scripts/cleanup.sh

##@ Testes e Validação

test: ## Executa testes de smoke na aplicação
	@echo "$(GREEN)Executando smoke tests...$(NC)"
	@kubectl get pods -n $(NAMESPACE) | grep -q "Running" || (echo "$(YELLOW)Pods não estão rodando!$(NC)" && exit 1)
	@echo "✅ Todos os pods estão rodando"
	@kubectl get hpa -n $(NAMESPACE) | grep -q "frontend" || (echo "$(YELLOW)HPA não configurado!$(NC)" && exit 1)
	@echo "✅ HPA configurado"
	@echo "$(GREEN)Smoke tests passaram!$(NC)"

validate: ## Valida os manifests Kubernetes
	@echo "$(GREEN)Validando manifests...$(NC)"
	@kubectl apply --dry-run=client -f k8s/
	@echo "✅ Manifests válidos"

##@ Status e Monitoramento

status: ## Mostra status de todos os recursos
	@echo "$(BLUE)========== CLUSTER ==========$(NC)"
	@kubectl cluster-info
	@echo ""
	@echo "$(BLUE)========== NODES ==========$(NC)"
	@kubectl get nodes
	@echo ""
	@echo "$(BLUE)========== APLICAÇÃO ($(NAMESPACE)) ==========$(NC)"
	@kubectl get pods,svc,hpa -n $(NAMESPACE)
	@echo ""
	@echo "$(BLUE)========== MONITORING ($(MONITORING_NS)) ==========$(NC)"
	@kubectl get pods -n $(MONITORING_NS)
	@echo ""
	@echo "$(BLUE)========== LOGGING ($(LOGGING_NS)) ==========$(NC)"
	@kubectl get pods -n $(LOGGING_NS)

logs: ## Mostra logs da aplicação (frontend)
	@kubectl logs -n $(NAMESPACE) -l app=frontend --tail=100 -f

logs-all: ## Mostra logs de todos os pods
	@kubectl logs -n $(NAMESPACE) --all-containers=true --tail=50

events: ## Mostra eventos recentes
	@kubectl get events -n $(NAMESPACE) --sort-by='.lastTimestamp' | tail -20

top: ## Mostra uso de recursos
	@echo "$(BLUE)========== NODES ==========$(NC)"
	@kubectl top nodes
	@echo ""
	@echo "$(BLUE)========== PODS ==========$(NC)"
	@kubectl top pods -n $(NAMESPACE)

##@ Port Forwarding

port-forward-app: ## Port forward para a aplicação (localhost:8080)
	@echo "$(GREEN)Acessando aplicação em http://localhost:8080$(NC)"
	@kubectl port-forward -n $(NAMESPACE) svc/frontend-external 8080:80

port-forward-grafana: ## Port forward para Grafana (localhost:3000)
	@echo "$(GREEN)Acessando Grafana em http://localhost:3000$(NC)"
	@echo "$(YELLOW)Usuário: admin$(NC)"
	@echo "$(YELLOW)Senha: $$(kubectl get secret -n $(MONITORING_NS) prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode)$(NC)"
	@kubectl port-forward -n $(MONITORING_NS) svc/prometheus-grafana 3000:80

port-forward-prometheus: ## Port forward para Prometheus (localhost:9090)
	@echo "$(GREEN)Acessando Prometheus em http://localhost:9090$(NC)"
	@kubectl port-forward -n $(MONITORING_NS) svc/prometheus-kube-prometheus-prometheus 9090:9090

port-forward-kibana: ## Port forward para Kibana (localhost:5601)
	@echo "$(GREEN)Acessando Kibana em http://localhost:5601$(NC)"
	@kubectl port-forward -n $(LOGGING_NS) svc/kibana-kibana 5601:5601

port-forward-elasticsearch: ## Port forward para Elasticsearch (localhost:9200)
	@echo "$(GREEN)Acessando Elasticsearch em http://localhost:9200$(NC)"
	@kubectl port-forward -n $(LOGGING_NS) svc/elasticsearch-master 9200:9200

##@ Operações

scale-up: ## Escala a aplicação para 5 réplicas
	@echo "$(GREEN)Escalando para 5 réplicas...$(NC)"
	@kubectl scale deployment frontend -n $(NAMESPACE) --replicas=5
	@kubectl scale deployment cartservice -n $(NAMESPACE) --replicas=5

scale-down: ## Escala a aplicação para 2 réplicas
	@echo "$(GREEN)Escalando para 2 réplicas...$(NC)"
	@kubectl scale deployment frontend -n $(NAMESPACE) --replicas=2
	@kubectl scale deployment cartservice -n $(NAMESPACE) --replicas=2

restart: ## Reinicia todos os deployments
	@echo "$(GREEN)Reiniciando deployments...$(NC)"
	@kubectl rollout restart deployment -n $(NAMESPACE)

rollback: ## Faz rollback do último deployment
	@echo "$(YELLOW)Fazendo rollback...$(NC)"
	@kubectl rollout undo deployment/frontend -n $(NAMESPACE)
	@kubectl rollout undo deployment/cartservice -n $(NAMESPACE)

##@ Troubleshooting

describe-pods: ## Descreve todos os pods (útil para debug)
	@kubectl describe pods -n $(NAMESPACE)

get-errors: ## Mostra pods com erro
	@kubectl get pods -n $(NAMESPACE) --field-selector=status.phase!=Running

debug-frontend: ## Abre shell no pod do frontend
	@kubectl exec -it -n $(NAMESPACE) $$(kubectl get pod -n $(NAMESPACE) -l app=frontend -o jsonpath='{.items[0].metadata.name}') -- /bin/sh

debug-logs: ## Mostra logs de pods com problema
	@echo "$(YELLOW)Pods com problemas:$(NC)"
	@kubectl get pods -n $(NAMESPACE) --field-selector=status.phase!=Running -o name | while read pod; do \
		echo "$(BLUE)========== $$pod ==========$(NC)"; \
		kubectl logs -n $(NAMESPACE) $$pod --tail=50 || true; \
	done

check-metrics: ## Verifica se métricas estão disponíveis
	@echo "$(GREEN)Verificando Metrics Server...$(NC)"
	@kubectl top nodes || echo "$(YELLOW)Metrics Server não disponível$(NC)"
	@echo ""
	@echo "$(GREEN)Verificando métricas dos pods...$(NC)"
	@kubectl top pods -n $(NAMESPACE) || echo "$(YELLOW)Métricas dos pods não disponíveis$(NC)"

check-elk: ## Verifica status do ELK Stack
	@echo "$(GREEN)Verificando Elasticsearch...$(NC)"
	@kubectl port-forward -n $(LOGGING_NS) svc/elasticsearch-master 9200:9200 > /dev/null 2>&1 & \
		sleep 3; \
		curl -s http://localhost:9200/_cluster/health?pretty || echo "$(YELLOW)Elasticsearch não disponível$(NC)"; \
		pkill -f "port-forward.*elasticsearch"
	@echo ""
	@echo "$(GREEN)Verificando índices...$(NC)"
	@kubectl port-forward -n $(LOGGING_NS) svc/elasticsearch-master 9200:9200 > /dev/null 2>&1 & \
		sleep 3; \
		curl -s http://localhost:9200/_cat/indices?v || echo "$(YELLOW)Não foi possível listar índices$(NC)"; \
		pkill -f "port-forward.*elasticsearch"

##@ Desenvolvimento

lint: ## Valida Dockerfiles e YAML
	@echo "$(GREEN)Linting Dockerfile...$(NC)"
	@docker run --rm -i hadolint/hadolint < Dockerfile || true
	@echo ""
	@echo "$(GREEN)Linting YAML...$(NC)"
	@yamllint -c .yamllint.yml k8s/ || true

format: ## Formata arquivos YAML
	@echo "$(GREEN)Formatando YAML...$(NC)"
	@find k8s/ -name "*.yaml" -exec sed -i '' 's/[[:space:]]*$$//' {} \;

##@ Informações

info: ## Mostra informações do ambiente
	@echo "$(BLUE)=========================================="
	@echo "SRE Pleno Test - Informações do Ambiente"
	@echo "==========================================$(NC)"
	@echo ""
	@echo "Cluster: $(CLUSTER_NAME)"
	@echo "Context: $$(kubectl config current-context)"
	@echo "Namespaces:"
	@echo "  - Aplicação: $(NAMESPACE)"
	@echo "  - Monitoring: $(MONITORING_NS)"
	@echo "  - Logging: $(LOGGING_NS)"
	@echo ""
	@echo "$(GREEN)Acesso rápido:$(NC)"
	@echo "  - App:         make port-forward-app"
	@echo "  - Grafana:     make port-forward-grafana"
	@echo "  - Prometheus:  make port-forward-prometheus"
	@echo "  - Kibana:      make port-forward-kibana"
	@echo ""
	@echo "$(GREEN)Comandos úteis:$(NC)"
	@echo "  - Status:      make status"
	@echo "  - Logs:        make logs"
	@echo "  - Troubleshoot: make debug-logs"
	@echo ""

version: ## Mostra versões das ferramentas
	@echo "$(BLUE)Versões das ferramentas:$(NC)"
	@echo "kubectl: $$(kubectl version --client --short 2>/dev/null || echo 'não instalado')"
	@echo "helm: $$(helm version --short 2>/dev/null || echo 'não instalado')"
	@echo "kind: $$(kind version 2>/dev/null || echo 'não instalado')"
	@echo "docker: $$(docker --version 2>/dev/null || echo 'não instalado')"

##@ Quick Start

quickstart: setup deploy ## Setup completo do zero (cluster + app + observability)
	@echo ""
	@echo "$(GREEN)=========================================="
	@echo "✅ Setup completo concluído!"
	@echo "==========================================$(NC)"
	@echo ""
	@echo "Próximos passos:"
	@echo "  1. Verificar status: make status"
	@echo "  2. Acessar app: make port-forward-app"
	@echo "  3. Acessar Grafana: make port-forward-grafana"
	@echo "  4. Acessar Kibana: make port-forward-kibana"
	@echo ""

.DEFAULT_GOAL := help

