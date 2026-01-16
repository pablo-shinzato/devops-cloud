#!/bin/bash

################################################################################
# Script de Deploy da Aplicação Online Boutique
# Autor: Pablo Shizato
# Data: Janeiro 2026
# Descrição: Faz deploy completo da aplicação no cluster Kubernetes
################################################################################

set -u
set -o pipefail
# Não usar set -e para permitir continuar mesmo se alguns deployments falharem

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variáveis
NAMESPACE="online-boutique"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
K8S_DIR="$PROJECT_ROOT/k8s"

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
# Verificações
################################################################################

log_info "Verificando cluster Kubernetes..."

if ! kubectl cluster-info &> /dev/null; then
    log_error "Cluster Kubernetes não está acessível!"
    log_info "Execute primeiro: ./scripts/setup-cluster.sh"
    exit 1
fi

log_success "Cluster acessível!"

################################################################################
# Criar namespace se não existir
################################################################################

log_info "Verificando namespace '$NAMESPACE'..."

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

log_success "Namespace '$NAMESPACE' pronto!"

################################################################################
# Aplicar manifests Kubernetes
################################################################################

log_info "Aplicando manifests Kubernetes..."

# Aplicar em ordem
log_info "1/4 - Aplicando namespace e configmaps..."
kubectl apply -f "$K8S_DIR/00-namespace.yaml"
kubectl apply -f "$K8S_DIR/01-configmap.yaml"

log_info "2/4 - Aplicando deployments..."
kubectl apply -f "$K8S_DIR/02-deployments.yaml"

log_info "3/4 - Aplicando services..."
kubectl apply -f "$K8S_DIR/03-services.yaml"

log_info "4/4 - Aplicando HPAs..."
kubectl apply -f "$K8S_DIR/04-hpa.yaml"

log_success "Todos os manifests aplicados!"

################################################################################
# Aguardar pods ficarem prontos
################################################################################

log_info "Aguardando pods ficarem prontos (pode levar alguns minutos)..."

# Verificar recursos disponíveis
log_info "Verificando recursos disponíveis no cluster..."
NODE_CPU=$(kubectl describe node | grep -A 5 "Allocated resources" | grep cpu | awk '{print $2}' || echo "unknown")
NODE_MEM=$(kubectl describe node | grep -A 5 "Allocated resources" | grep memory | awk '{print $2}' || echo "unknown")
log_info "Recursos alocados no node: CPU=$NODE_CPU, Memory=$NODE_MEM"

# Aguardar deployments rollout (com timeout mais tolerante)
DEPLOYMENTS=$(kubectl get deployments -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')

SUCCESSFUL_DEPLOYMENTS=0
FAILED_DEPLOYMENTS=0

for deployment in $DEPLOYMENTS; do
    log_info "Aguardando deployment '$deployment'..."
    if kubectl rollout status deployment/"$deployment" -n "$NAMESPACE" --timeout=300s 2>&1; then
        SUCCESSFUL_DEPLOYMENTS=$((SUCCESSFUL_DEPLOYMENTS + 1))
        log_success "Deployment '$deployment' está pronto"
    else
        FAILED_DEPLOYMENTS=$((FAILED_DEPLOYMENTS + 1))
        log_warning "Timeout aguardando deployment '$deployment'"
        
        # Verificar por que está falhando
        PENDING_PODS=$(kubectl get pods -n "$NAMESPACE" -l app="${deployment}" --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l || echo "0")
        if [ "$PENDING_PODS" -gt 0 ]; then
            log_warning "  → $PENDING_PODS pod(s) em estado Pending (possivelmente recursos insuficientes)"
            log_info "  → Execute: kubectl describe pod -n $NAMESPACE -l app=${deployment} | grep -A 10 Events"
        fi
    fi
done

log_info "Deployments: $SUCCESSFUL_DEPLOYMENTS prontos, $FAILED_DEPLOYMENTS com problemas"

if [ "$FAILED_DEPLOYMENTS" -gt 0 ]; then
    log_warning "Alguns deployments não estão prontos. Isso pode ser devido a recursos insuficientes no cluster."
    log_warning "Em um cluster single-node, considere reduzir o número de réplicas ou recursos solicitados."
else
    log_success "Deployments prontos!"
fi

################################################################################
# Verificar status
################################################################################

log_info "Verificando status da aplicação..."

echo ""
echo "=========================================="
echo "Pods:"
echo "=========================================="
kubectl get pods -n "$NAMESPACE" -o wide

echo ""
echo "=========================================="
echo "Services:"
echo "=========================================="
kubectl get svc -n "$NAMESPACE"

echo ""
echo "=========================================="
echo "HPAs:"
echo "=========================================="
kubectl get hpa -n "$NAMESPACE"

################################################################################
# Verificar health
################################################################################

log_info "Verificando health dos serviços..."

UNHEALTHY_PODS=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)

if [ "$UNHEALTHY_PODS" -gt 0 ]; then
    log_warning "Existem $UNHEALTHY_PODS pods não saudáveis!"
    echo ""
    echo "Pods com problemas:"
    kubectl get pods -n "$NAMESPACE" --field-selector=status.phase!=Running
    echo ""
    log_info "Execute 'kubectl describe pod <pod-name> -n $NAMESPACE' para mais detalhes"
else
    log_success "Todos os pods estão saudáveis!"
fi

################################################################################
# Informações de acesso
################################################################################

echo ""
echo "=========================================="
log_success "Deploy da aplicação concluído!"
echo "=========================================="
echo ""
echo "Para acessar a aplicação:"
echo ""
echo "  1. Via Port Forward:"
echo "     kubectl port-forward -n $NAMESPACE svc/frontend-external 8080:80"
echo "     Acesse: http://localhost:8080"
echo ""
echo "  2. Via LoadBalancer (se disponível):"
EXTERNAL_IP=$(kubectl get svc frontend-external -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
if [ "$EXTERNAL_IP" != "pending" ] && [ -n "$EXTERNAL_IP" ]; then
    echo "     http://$EXTERNAL_IP"
else
    echo "     Aguardando IP externo..."
fi
echo ""
echo "Comandos úteis:"
echo "  - Ver logs: kubectl logs -n $NAMESPACE -l app=frontend --tail=100"
echo "  - Ver eventos: kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'"
echo "  - Escalar: kubectl scale deployment frontend -n $NAMESPACE --replicas=3"
echo ""

