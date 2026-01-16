#!/bin/bash

################################################################################
# Script de Setup do Cluster Kubernetes para SRE Pleno Test
# Autor: Pablo Shizato
# Data: Janeiro 2026
# Descrição: Provisiona cluster Kind e instala dependências básicas
################################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable
set -o pipefail  # Exit on pipe failure

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variáveis
CLUSTER_NAME="sre-pleno"
KUBECONFIG_PATH="$HOME/.kube/config"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

################################################################################
# Funções auxiliares
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
        log_error "$1 não está instalado. Por favor, instale antes de continuar."
        exit 1
    fi
}

################################################################################
# Verificações de pré-requisitos
################################################################################

log_info "Verificando pré-requisitos..."

check_command "docker"
check_command "kubectl"
check_command "kind"
check_command "helm"

# Verificar se Docker está rodando
if ! docker info > /dev/null 2>&1; then
    log_error "Docker não está rodando. Por favor, inicie o Docker antes de continuar."
    exit 1
fi

# Verificar recursos do Docker
log_info "Verificando recursos disponíveis..."
DOCKER_MEM=$(docker info 2>/dev/null | grep "Total Memory" | awk '{print $3}' || echo "unknown")
log_info "Memória Docker disponível: $DOCKER_MEM"

log_success "Todos os pré-requisitos estão instalados!"

################################################################################
# Criar cluster Kind
################################################################################

log_info "Verificando se cluster '$CLUSTER_NAME' já existe..."

if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    log_warning "Cluster '$CLUSTER_NAME' já existe."
    read -p "Deseja recriar o cluster? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Deletando cluster existente..."
        kind delete cluster --name "$CLUSTER_NAME"
    else
        log_info "Usando cluster existente."
        kubectl cluster-info --context "kind-${CLUSTER_NAME}"
        exit 0
    fi
fi

log_info "Criando cluster Kind '$CLUSTER_NAME'..."

# Limpar qualquer cluster parcial que possa ter ficado
if docker ps -a | grep -q "${CLUSTER_NAME}"; then
    log_warning "Encontrados containers parciais do cluster. Limpando..."
    kind delete cluster --name "$CLUSTER_NAME" 2>/dev/null || true
    # Limpar containers órfãos
    docker ps -a --filter "name=${CLUSTER_NAME}" --format "{{.ID}}" | xargs -r docker rm -f 2>/dev/null || true
fi

# Função de diagnóstico detalhado
run_diagnostics() {
    log_info "========== DIAGNÓSTICO DETALHADO =========="
    
    # Informações do sistema
    log_info "Versão do Kind:"
    kind version 2>&1 || echo "Kind não encontrado"
    
    log_info "Versão do Docker:"
    docker --version 2>&1 || echo "Docker não encontrado"
    
    log_info "Informações do Docker:"
    docker info 2>&1 | grep -E "(Total Memory|CPUs|OSType|Operating System)" || true
    
    log_info "Recursos disponíveis:"
    docker system df 2>&1 || true
    
    # Verificar containers do cluster
    log_info "Containers relacionados ao cluster:"
    docker ps -a --filter "name=${CLUSTER_NAME}" 2>&1 || true
    
    # Verificar logs do control plane se existir
    CP_CONTAINER=$(docker ps -a --filter "name=${CLUSTER_NAME}-control-plane" --format "{{.ID}}" | head -1)
    if [ -n "$CP_CONTAINER" ]; then
        log_info "Logs do control plane (últimas 50 linhas):"
        docker logs "$CP_CONTAINER" --tail 50 2>&1 | tail -30 || true
        
        log_info "Status do container:"
        docker inspect "$CP_CONTAINER" --format='{{.State.Status}} - {{.State.Error}}' 2>&1 || true
    fi
    
    # Verificar portas
    log_info "Verificando portas em uso:"
    for port in 6443 80 443 30000 30001; do
        if command -v lsof > /dev/null 2>&1; then
            if lsof -i :$port > /dev/null 2>&1; then
                log_warning "Porta $port está em uso:"
                lsof -i :$port 2>&1 | head -3 || true
            fi
        elif command -v netstat > /dev/null 2>&1; then
            if netstat -tuln 2>/dev/null | grep -q ":$port "; then
                log_warning "Porta $port está em uso"
            fi
        fi
    done
    
    log_info "========== FIM DO DIAGNÓSTICO =========="
}

# Tentar criar o cluster com configuração completa
log_info "Tentando criar cluster com configuração completa (3 nodes)..."
if ! kind create cluster \
    --name "$CLUSTER_NAME" \
    --config "$PROJECT_ROOT/docs/kind-config.yaml" \
    --wait 10m 2>&1 | tee /tmp/kind-create.log; then
    
    log_error "Falha ao criar cluster com configuração completa."
    run_diagnostics
    
    # Tentar criar cluster simplificado (single node) como fallback
    log_warning "Tentando criar cluster simplificado (single node) como fallback..."
    
    if kind create cluster \
        --name "${CLUSTER_NAME}-simple" \
        --wait 10m 2>&1; then
        
        log_success "Cluster simplificado criado com sucesso!"
        log_warning "Usando cluster simplificado (1 node) em vez de 3 nodes."
        log_warning "Algumas funcionalidades podem ser limitadas."
        CLUSTER_NAME="${CLUSTER_NAME}-simple"
    else
        log_error "Falha ao criar cluster simplificado também."
        log_error ""
        log_error "Cluster não pôde ser criado. Verifique:"
        log_error "  1. Docker tem recursos suficientes (mínimo 4GB RAM, 2 CPUs)"
        log_error "  2. Docker está rodando corretamente: docker info"
        log_error "  3. Não há conflitos de portas (6443, 80, 443)"
        log_error "  4. Sistema de arquivos tem espaço suficiente"
        log_error "  5. Versão do Kind é compatível: kind version"
        log_error ""
        log_error "Tente manualmente:"
        log_error "  kind create cluster --name sre-pleno"
        log_error "  Ou consulte: docs/troubleshooting.md"
        
        exit 1
    fi
fi

log_success "Cluster Kind criado com sucesso!"

################################################################################
# Configurar kubectl context
################################################################################

log_info "Configurando kubectl context..."

# Aguardar um pouco para garantir que o cluster está totalmente pronto
sleep 5

if ! kubectl cluster-info --context "kind-${CLUSTER_NAME}" 2>&1; then
    log_warning "Aguardando cluster estar totalmente pronto..."
    sleep 10
    kubectl cluster-info --context "kind-${CLUSTER_NAME}" || {
        log_error "Não foi possível conectar ao cluster."
        exit 1
    }
fi

kubectl config use-context "kind-${CLUSTER_NAME}"

log_success "kubectl configurado para usar o cluster '$CLUSTER_NAME'"

################################################################################
# Instalar Metrics Server
################################################################################

log_info "Instalando Metrics Server..."

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch para funcionar com Kind (insecure TLS)
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]' || true

# Aguardar metrics-server estar pronto (mas não bloquear se demorar muito)
log_info "Aguardando Metrics Server estar pronto..."
if kubectl wait --for=condition=ready pod -n kube-system -l k8s-app=metrics-server --timeout=120s 2>/dev/null; then
    log_success "Metrics Server está pronto!"
else
    log_warning "Metrics Server pode não estar totalmente pronto, mas continuando..."
    log_warning "Você pode verificar depois com: kubectl get pods -n kube-system -l k8s-app=metrics-server"
fi

log_success "Metrics Server instalado!"

################################################################################
# Criar namespaces
################################################################################

log_info "Criando namespaces..."

kubectl create namespace online-boutique --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -

log_success "Namespaces criados!"

################################################################################
# Aguardar cluster estar pronto
################################################################################

log_info "Aguardando cluster estar completamente pronto..."

# Aguardar nodes estarem prontos
kubectl wait --for=condition=ready node --all --timeout=300s || {
    log_warning "Alguns nodes podem não estar prontos, mas continuando..."
}

# Verificar se pelo menos o API server está respondendo
log_info "Verificando se API server está respondendo..."
RETRY_COUNT=0
MAX_RETRIES=30
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if kubectl cluster-info > /dev/null 2>&1; then
        log_success "API server está respondendo"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            sleep 2
        fi
    fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    log_error "API server não está respondendo após $MAX_RETRIES tentativas!"
    exit 1
fi

# Verificar status geral dos pods do sistema (informacional, não bloqueante)
log_info "Verificando status dos componentes do sistema..."
READY_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -c "Running" || echo "0")
TOTAL_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | wc -l || echo "0")
log_info "Pods do sistema: $READY_PODS/$TOTAL_PODS rodando"

if [ "$READY_PODS" -lt 3 ]; then
    log_warning "Poucos pods do sistema estão rodando, mas continuando..."
    log_warning "Alguns componentes podem ainda estar inicializando"
else
    log_success "Componentes do sistema estão operacionais"
fi

log_success "Cluster está pronto!"

################################################################################
# Informações finais
################################################################################

echo ""
echo "=========================================="
log_success "Setup do cluster concluído com sucesso!"
echo "=========================================="
echo ""
echo "Informações do Cluster:"
echo "  Nome: $CLUSTER_NAME"
echo "  Context: kind-$CLUSTER_NAME"
echo "  Nodes:"
kubectl get nodes
echo ""
echo "Próximos passos:"
echo "  1. Deploy da aplicação: ./scripts/deploy-app.sh"
echo "  2. Deploy observabilidade: ./scripts/deploy-observability.sh"
echo "  3. Verificar status: kubectl get pods --all-namespaces"
echo ""

