#!/bin/bash

################################################################################
# Script de Deploy do Stack de Observabilidade
# Autor: Pablo Shizato
# Data: Janeiro 2026
# Descrição: Instala Prometheus, Grafana, ELK Stack e configura dashboards
################################################################################

set -u
set -o pipefail
# Não usar set -e para permitir continuar mesmo se alguns componentes falharem

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variáveis
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MONITORING_DIR="$PROJECT_ROOT/monitoring"
ELK_DIR="$PROJECT_ROOT/elk"

################################################################################
# Funções
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "$1 não está instalado!"
        exit 1
    fi
}

################################################################################
# Verificações
################################################################################

log_info "Verificando pré-requisitos..."

check_command "kubectl"
check_command "helm"

if ! kubectl cluster-info &> /dev/null; then
    log_error "Cluster Kubernetes não está acessível!"
    exit 1
fi

log_success "Pré-requisitos OK!"

################################################################################
# Adicionar repositórios Helm
################################################################################

log_info "Adicionando repositórios Helm..."

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add elastic https://helm.elastic.co
helm repo update

log_success "Repositórios Helm adicionados!"

################################################################################
# Deploy Prometheus Stack (inclui Grafana)
################################################################################

log_info "Instalando Prometheus Stack (Prometheus + Grafana + Alertmanager)..."

helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --create-namespace \
    --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
    --set prometheus.prometheusSpec.retention=7d \
    --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=10Gi \
    --set grafana.adminPassword=admin123 \
    --set grafana.persistence.enabled=true \
    --set grafana.persistence.size=5Gi \
    --wait \
    --timeout 10m

log_success "Prometheus Stack instalado!"

################################################################################
# Aplicar ServiceMonitors e Alerting Rules
################################################################################

log_info "Aplicando ServiceMonitors e regras de alerta..."

kubectl apply -f "$MONITORING_DIR/prometheus-servicemonitor.yaml"
kubectl apply -f "$MONITORING_DIR/alerting-rules.yaml"

log_success "ServiceMonitors e alertas configurados!"

################################################################################
# Deploy Elasticsearch
################################################################################

log_info "Instalando Elasticsearch (com recursos mínimos para cluster single-node)..."

# Verificar recursos disponíveis
log_info "Verificando recursos disponíveis no cluster..."
AVAILABLE_CPU=$(kubectl top nodes --no-headers 2>/dev/null | awk '{print $3}' | sed 's/m//' | head -1 || echo "unknown")
AVAILABLE_MEM=$(kubectl top nodes --no-headers 2>/dev/null | awk '{print $5}' | head -1 || echo "unknown")
log_info "Recursos disponíveis: CPU=$AVAILABLE_CPU, Memory=$AVAILABLE_MEM"

# Instalar Elasticsearch com recursos mínimos
if helm upgrade --install elasticsearch elastic/elasticsearch \
    --namespace logging \
    --create-namespace \
    --set replicas=1 \
    --set minimumMasterNodes=1 \
    --set resources.requests.memory=512Mi \
    --set resources.requests.cpu=200m \
    --set resources.limits.memory=1Gi \
    --set resources.limits.cpu=1000m \
    --set persistence.enabled=false \
    --set volumeClaimTemplate.resources.requests.storage=5Gi \
    --set esJavaOpts="-Xms256m -Xmx256m" \
    --wait \
    --timeout 15m 2>&1; then
    
    log_success "Elasticsearch instalado!"
else
    log_error "Falha ao instalar Elasticsearch. Tentando continuar sem ele..."
    log_warning "Elasticsearch requer recursos significativos. Em clusters pequenos, pode não ser possível instalá-lo."
    log_warning "Você pode tentar instalar manualmente depois com mais recursos disponíveis."
    
    # Tentar desinstalar se foi parcialmente instalado
    helm uninstall elasticsearch --namespace logging 2>/dev/null || true
    
    # Pular Kibana e Filebeat também, já que dependem do Elasticsearch
    log_warning "Pulando Kibana e Filebeat (dependem do Elasticsearch)"
    SKIP_ELK=true
fi

################################################################################
# Deploy Kibana
################################################################################

if [ "${SKIP_ELK:-false}" != "true" ]; then
    log_info "Instalando Kibana..."
    
    if helm upgrade --install kibana elastic/kibana \
        --namespace logging \
        --set elasticsearchHosts="http://elasticsearch-master:9200" \
        --set resources.requests.memory=256Mi \
        --set resources.requests.cpu=100m \
        --set resources.limits.memory=512Mi \
        --set resources.limits.cpu=500m \
        --wait \
        --timeout 10m 2>&1; then
        
        log_success "Kibana instalado!"
    else
        log_warning "Falha ao instalar Kibana. Continuando sem ele..."
        SKIP_ELK=true
    fi
else
    log_warning "Pulando Kibana (Elasticsearch não está disponível)"
fi

################################################################################
# Deploy Filebeat
################################################################################

if [ "${SKIP_ELK:-false}" != "true" ]; then
    log_info "Instalando Filebeat (DaemonSet)..."
    
    if kubectl apply -f "$ELK_DIR/filebeat.yaml" 2>&1; then
        log_success "Filebeat instalado!"
    else
        log_warning "Falha ao instalar Filebeat. Continuando..."
    fi
else
    log_warning "Pulando Filebeat (Elasticsearch não está disponível)"
fi

################################################################################
# Deploy Logstash
################################################################################

if [ "${SKIP_ELK:-false}" != "true" ]; then
    log_info "Instalando Logstash..."
    
    if kubectl apply -f "$ELK_DIR/logstash-configmap.yaml" 2>&1 && \
       kubectl apply -f "$ELK_DIR/logstash-deployment.yaml" 2>&1; then
        log_success "Logstash instalado!"
    else
        log_warning "Falha ao instalar Logstash. Continuando..."
    fi
else
    log_warning "Pulando Logstash (Elasticsearch não está disponível)"
fi

################################################################################
# Aguardar pods ficarem prontos
################################################################################

log_info "Aguardando pods de observabilidade ficarem prontos..."

kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=300s || log_warning "Timeout Prometheus"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s || log_warning "Timeout Grafana"

if [ "${SKIP_ELK:-false}" != "true" ]; then
    kubectl wait --for=condition=ready pod -l app=elasticsearch-master -n logging --timeout=300s || log_warning "Timeout Elasticsearch"
    kubectl wait --for=condition=ready pod -l app=kibana -n logging --timeout=300s || log_warning "Timeout Kibana"
fi

log_success "Pods de observabilidade prontos!"

################################################################################
# Importar Dashboards
################################################################################

log_info "Importando dashboards..."

# Nota: Import automático de dashboards requer API do Grafana
# Por enquanto, os arquivos JSON estão disponíveis para import manual

log_info "Dashboards disponíveis em:"
log_info "  - Grafana: $MONITORING_DIR/grafana-dashboard.json"
log_info "  - Kibana: $ELK_DIR/kibana-dashboard.json"
log_info "  - Kibana Alerts: $ELK_DIR/kibana-alerts.json"

################################################################################
# Status e informações de acesso
################################################################################

echo ""
echo "=========================================="
log_success "Stack de Observabilidade instalado!"
echo "=========================================="
echo ""

echo "Pods Monitoring:"
kubectl get pods -n monitoring

echo ""
echo "Pods Logging:"
kubectl get pods -n logging

echo ""
echo "=========================================="
echo "Informações de Acesso:"
echo "=========================================="
echo ""

# Grafana
GRAFANA_PASSWORD=$(kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode)
echo "📊 GRAFANA:"
echo "   Port Forward: kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
echo "   URL: http://localhost:3000"
echo "   Usuário: admin"
echo "   Senha: $GRAFANA_PASSWORD"
echo ""

# Prometheus
echo "🔥 PROMETHEUS:"
echo "   Port Forward: kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
echo "   URL: http://localhost:9090"
echo ""

# Kibana
if [ "${SKIP_ELK:-false}" != "true" ]; then
    echo "📈 KIBANA:"
    echo "   Port Forward: kubectl port-forward -n logging svc/kibana-kibana 5601:5601"
    echo "   URL: http://localhost:5601"
    echo ""
    
    # Elasticsearch
    echo "🔍 ELASTICSEARCH:"
    echo "   Port Forward: kubectl port-forward -n logging svc/elasticsearch-master 9200:9200"
    echo "   URL: http://localhost:9200"
    echo "   Health: curl http://localhost:9200/_cluster/health?pretty"
    echo ""
else
    echo "⚠️  ELK STACK:"
    echo "   ELK Stack não foi instalado devido a recursos insuficientes."
    echo "   Para instalar manualmente, execute:"
    echo "   helm install elasticsearch elastic/elasticsearch --namespace logging --set resources.requests.memory=512Mi"
    echo ""
fi

echo "=========================================="
echo "Próximos Passos:"
echo "=========================================="
echo ""
echo "1. Acessar Grafana e importar dashboard:"
echo "   - Arquivo: monitoring/grafana-dashboard.json"
echo "   - Menu: Dashboards > Import > Upload JSON"
echo ""
echo "2. Acessar Kibana e configurar index pattern:"
echo "   - Menu: Stack Management > Index Patterns"
echo "   - Pattern: app-logs-staging-*"
echo "   - Time field: @timestamp"
echo ""
echo "3. Importar dashboard do Kibana:"
echo "   - Arquivo: elk/kibana-dashboard.json"
echo "   - Menu: Stack Management > Saved Objects > Import"
echo ""
echo "4. Verificar métricas estão sendo coletadas:"
echo "   - Prometheus Targets: http://localhost:9090/targets"
echo "   - Grafana Explore: http://localhost:3000/explore"
echo ""
echo "5. Verificar logs estão chegando:"
echo "   - Kibana Discover: http://localhost:5601/app/discover"
echo "   - Elasticsearch indices: curl http://localhost:9200/_cat/indices?v"
echo ""

