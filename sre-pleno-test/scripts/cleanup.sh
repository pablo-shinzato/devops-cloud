#!/bin/bash

################################################################################
# Script de Limpeza do Ambiente
# Autor: Pablo Shizato
# Data: Janeiro 2026
# Descrição: Remove todos os recursos criados pelo projeto
################################################################################

set -e
set -u
set -o pipefail

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variáveis
CLUSTER_NAME="sre-pleno"

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

################################################################################
# Confirmação
################################################################################

echo ""
echo "=========================================="
log_warning "ATENÇÃO: Este script irá remover:"
echo "=========================================="
echo "  - Cluster Kind '$CLUSTER_NAME'"
echo "  - Todos os namespaces e recursos"
echo "  - Volumes persistentes"
echo "  - Configurações do kubectl"
echo ""

read -p "Tem certeza que deseja continuar? (yes/NO): " -r
echo

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    log_info "Operação cancelada."
    exit 0
fi

################################################################################
# Deletar recursos Kubernetes (opcional)
################################################################################

if kubectl cluster-info &> /dev/null; then
    log_info "Deletando recursos Kubernetes..."
    
    # Deletar namespaces (isso deleta todos os recursos dentro deles)
    log_info "Deletando namespace 'online-boutique'..."
    kubectl delete namespace online-boutique --ignore-not-found=true --timeout=60s || log_warning "Timeout deletando namespace online-boutique"
    
    log_info "Deletando namespace 'monitoring'..."
    kubectl delete namespace monitoring --ignore-not-found=true --timeout=60s || log_warning "Timeout deletando namespace monitoring"
    
    log_info "Deletando namespace 'logging'..."
    kubectl delete namespace logging --ignore-not-found=true --timeout=60s || log_warning "Timeout deletando namespace logging"
    
    log_success "Recursos Kubernetes deletados!"
else
    log_warning "Cluster não está acessível, pulando deleção de recursos."
fi

################################################################################
# Deletar cluster Kind
################################################################################

if command -v kind &> /dev/null; then
    if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
        log_info "Deletando cluster Kind '$CLUSTER_NAME'..."
        kind delete cluster --name "$CLUSTER_NAME"
        log_success "Cluster Kind deletado!"
    else
        log_warning "Cluster '$CLUSTER_NAME' não encontrado."
    fi
else
    log_warning "Kind não está instalado, pulando deleção do cluster."
fi

################################################################################
# Limpar contextos kubectl
################################################################################

log_info "Limpando contextos kubectl..."

if kubectl config get-contexts -o name | grep -q "kind-${CLUSTER_NAME}"; then
    kubectl config delete-context "kind-${CLUSTER_NAME}" || log_warning "Erro ao deletar context"
    log_success "Context kubectl removido!"
fi

if kubectl config get-clusters -o name | grep -q "kind-${CLUSTER_NAME}"; then
    kubectl config delete-cluster "kind-${CLUSTER_NAME}" || log_warning "Erro ao deletar cluster"
    log_success "Cluster kubectl removido!"
fi

################################################################################
# Limpar Helm releases (se ainda existirem)
################################################################################

if command -v helm &> /dev/null; then
    log_info "Verificando Helm releases..."
    
    # Listar e deletar releases
    for namespace in monitoring logging; do
        releases=$(helm list -n "$namespace" -q 2>/dev/null || echo "")
        if [ -n "$releases" ]; then
            log_info "Deletando Helm releases no namespace '$namespace'..."
            for release in $releases; do
                helm uninstall "$release" -n "$namespace" || log_warning "Erro ao deletar release $release"
            done
        fi
    done
    
    log_success "Helm releases removidos!"
fi

################################################################################
# Limpar volumes Docker (opcional)
################################################################################

read -p "Deseja limpar volumes Docker órfãos? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    if command -v docker &> /dev/null; then
        log_info "Limpando volumes Docker órfãos..."
        docker volume prune -f || log_warning "Erro ao limpar volumes"
        log_success "Volumes Docker limpos!"
    fi
fi

################################################################################
# Finalização
################################################################################

echo ""
echo "=========================================="
log_success "Limpeza concluída com sucesso!"
echo "=========================================="
echo ""
echo "O ambiente foi completamente removido."
echo ""
echo "Para recriar o ambiente, execute:"
echo "  1. ./scripts/setup-cluster.sh"
echo "  2. ./scripts/deploy-app.sh"
echo "  3. ./scripts/deploy-observability.sh"
echo ""

