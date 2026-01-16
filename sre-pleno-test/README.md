# SRE Pleno Test - Online Boutique (Google Microservices Demo)

## 📋 Visão Geral

Este projeto implementa uma solução completa de SRE para a aplicação **Online Boutique** do Google, uma aplicação de e-commerce baseada em microserviços. A solução abrange containerização, orquestração Kubernetes, observabilidade completa (métricas e logs), CI/CD e alerting.

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Ingress / Service (LoadBalancer)                    │   │
│  └────────────────┬─────────────────────────────────────┘   │
│                   │                                          │
│  ┌────────────────▼─────────────────────────────────────┐   │
│  │  Frontend Service (2 replicas + HPA)                 │   │
│  └────────────────┬─────────────────────────────────────┘   │
│                   │                                          │
│  ┌────────────────▼─────────────────────────────────────┐   │
│  │  Backend Services (Cart, Product, Checkout, etc.)    │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Observability Stack                                 │   │
│  │  • Prometheus (Métricas)                             │   │
│  │  • Grafana (Dashboards)                              │   │
│  │  • ELK Stack (Logs)                                  │   │
│  │    - Elasticsearch                                   │   │
│  │    - Filebeat (DaemonSet)                            │   │
│  │    - Logstash                                        │   │
│  │    - Kibana                                          │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Pré-requisitos

- Docker 20.10+
- Kubernetes 1.24+ (kind, k3s ou minikube)
- kubectl 1.24+
- Helm 3.10+
- Git

### 1. Provisionar Cluster Kubernetes Local

```bash
# Usando kind (recomendado)
kind create cluster --name sre-pleno --config docs/kind-config.yaml

# OU usando k3s
curl -sfL https://get.k3s.io | sh -

# OU usando minikube
minikube start --cpus=4 --memory=8192 --driver=docker
```

### 2. Deploy da Aplicação Online Boutique

```bash
# Aplicar todos os manifests Kubernetes
kubectl apply -f k8s/

# Verificar status dos pods
kubectl get pods -n default

# Aguardar todos os pods ficarem Ready
kubectl wait --for=condition=ready pod --all --timeout=300s
```

### 3. Deploy do Stack de Observabilidade

```bash
# Adicionar repositórios Helm
helm repo add elastic https://helm.elastic.co
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Deploy Prometheus
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

# Deploy Elasticsearch
helm install elasticsearch elastic/elasticsearch \
  --namespace logging --create-namespace \
  --set replicas=1 \
  --set minimumMasterNodes=1

# Deploy Kibana
helm install kibana elastic/kibana \
  --namespace logging \
  --set elasticsearchHosts="http://elasticsearch-master:9200"

# Deploy Filebeat
kubectl apply -f elk/filebeat.yaml

# Deploy Logstash
kubectl apply -f elk/logstash-configmap.yaml
kubectl apply -f elk/logstash-deployment.yaml

# Deploy Grafana (já incluído no kube-prometheus-stack)
# Acessar via port-forward
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

### 4. Acessar a Aplicação

```bash
# Obter IP do serviço frontend
kubectl get svc frontend-external

# Port-forward para acesso local
kubectl port-forward svc/frontend-external 8080:80

# Acessar no navegador
open http://localhost:8080
```

### 5. Acessar Dashboards de Observabilidade

```bash
# Grafana (usuário: admin, senha: prom-operator)
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Acesse: http://localhost:3000

# Kibana
kubectl port-forward -n logging svc/kibana-kibana 5601:5601
# Acesse: http://localhost:5601

# Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Acesse: http://localhost:9090
```

## 📦 Componentes

### **App: Online Boutique**
- **Descrição**: Aplicação de e-commerce baseada em microserviços (11 serviços)
- **Linguagens**: Go, Python, Node.js, Java, C#
- **Serviços**:
  - Frontend (Go)
  - Cart Service (C#)
  - Product Catalog (Go)
  - Currency Service (Node.js)
  - Payment Service (Node.js)
  - Shipping Service (Go)
  - Email Service (Python)
  - Checkout Service (Go)
  - Recommendation Service (Python)
  - Ad Service (Java)
  - Load Generator (Python)

### **K8s: Configurações Implementadas**
- ✅ **Deployments**: Todos os serviços com 2 réplicas
- ✅ **Services**: ClusterIP para serviços internos, LoadBalancer para frontend
- ✅ **ConfigMaps**: Configuração de APP_ENV=staging
- ✅ **HPA v2**: Autoscaling baseado em CPU > 70% e memória > 75%
- ✅ **Probes**: Liveness e Readiness em todos os serviços
- ✅ **Resources**: Requests e Limits configurados
- ✅ **Labels**: Padronização para service discovery

### **Monitoring: Métricas Coletadas**
- ✅ **Prometheus**: Coleta automática via ServiceMonitor
- ✅ **Métricas Aplicação**:
  - Request rate (req/s)
  - Request latency (p50, p95, p99)
  - Error rate (%)
  - CPU e Memory usage por pod
- ✅ **Métricas Kubernetes**:
  - Pod status e restarts
  - Node resources
  - HPA metrics
- ✅ **Dashboard Grafana**: 6 painéis principais
  - Overview geral da aplicação
  - Latência por serviço
  - Taxa de erro
  - Utilização de recursos
  - Request throughput
  - SLI/SLO tracking

### **CI/CD: Pipeline Implementado**
- ✅ **Plataforma**: GitHub Actions
- ✅ **Stages**:
  1. **Lint**: Validação de Dockerfiles (hadolint)
  2. **Build**: Construção de imagens Docker
  3. **Test**: Testes de segurança (Trivy)
  4. **Push**: Upload para Docker Hub
  5. **Deploy**: Deploy automático no K8s
- ✅ **Triggers**: Push e Pull Request
- ✅ **Rollback**: Automático em caso de falha

### **ELK: Stack de Logging**
- ✅ **Filebeat**: DaemonSet para coleta de logs dos pods
- ✅ **Logstash**: Pipeline de parsing e enriquecimento
- ✅ **Elasticsearch**: Armazenamento indexado
- ✅ **Kibana**: Visualização e dashboards
- ✅ **Index Pattern**: `app-logs-staging-*`
- ✅ **Campos Extraídos**:
  - Log level (INFO/WARN/ERROR)
  - Service name
  - Endpoint
  - Latency
  - Timestamp
  - Request ID

## 🎯 Decisões Técnicas

### 1. **Escolha da Aplicação: Online Boutique**
**Justificativa**: Aplicação oficial do Google para demonstração de microserviços, com:
- Arquitetura realista e complexa (11 microserviços)
- Múltiplas linguagens (Go, Python, Node.js, Java, C#)
- Já possui instrumentação para observabilidade
- Documentação completa e mantida pelo Google
- Ideal para demonstrar skills de SRE em ambiente multi-serviço

### 2. **Containerização: Multi-stage Builds**
**Justificativa**:
- Redução de 60-80% no tamanho das imagens
- Separação clara entre build e runtime
- Melhor segurança (sem ferramentas de build em produção)
- Usuário não-root em todos os containers

### 3. **Kubernetes: HPA v2 com Múltiplas Métricas**
**Justificativa**:
- CPU e memória como triggers de scaling
- Mais resiliente que HPA v1 (apenas CPU)
- Previne OOM kills
- Melhor utilização de recursos

### 4. **Observabilidade: Stack Prometheus + ELK**
**Justificativa**:
- **Prometheus**: Padrão de mercado para métricas
- **ELK**: Melhor solução para análise de logs complexos
- Separação de concerns (métricas vs logs)
- Integração nativa com Kubernetes

### 5. **Logging: Filebeat como DaemonSet**
**Justificativa**:
- Mais leve que Logstash como shipper
- Coleta automática de todos os pods
- Baixo overhead de recursos
- Fácil configuração via ConfigMap

### 6. **CI/CD: GitHub Actions**
**Justificativa**:
- Integração nativa com GitHub
- Free tier generoso
- Marketplace com actions prontas
- Fácil configuração YAML
- Suporte a matrix builds

### 7. **Cluster Local: kind (Kubernetes in Docker)**
**Justificativa**:
- Mais leve que minikube
- Suporte a múltiplos nós
- Configuração via YAML
- Melhor para CI/CD
- Rápido provisionamento

## 📊 Dashboards

### Grafana Dashboard
- **Arquivo**: `monitoring/grafana-dashboard.json`
- **Painéis**:
  1. Request Rate por serviço
  2. Latência P50/P95/P99
  3. Error Rate (%)
  4. CPU Usage por pod
  5. Memory Usage por pod
  6. Pod Restart Count

### Kibana Dashboard
- **Arquivo**: `elk/kibana-dashboard.json`
- **Visualizações**:
  1. Log Volume por Nível (Pie Chart)
  2. Top 10 Endpoints (Data Table)
  3. Erros ao Longo do Tempo (Line Chart)
  4. Distribuição de Latência (Histogram)
  5. Logs por Serviço (Bar Chart)
  6. Log Explorer (Discover)

## 🚨 Alertas Configurados

### Kibana Alerts
- **Trigger**: ≥ 20 erros nos últimos 5 minutos
- **Action**: Webhook para Slack/Email
- **Throttle**: 10 minutos

### Grafana Alerts
- **High Error Rate**: Error rate > 5% por 5 minutos
- **High Latency**: P95 latency > 1s por 5 minutos
- **Pod Crashes**: Pod restart > 3 vezes em 10 minutos
- **Resource Saturation**: CPU > 90% por 5 minutos

## 🧪 Testes e Validação

### Validar Deploy
```bash
# Verificar todos os pods
kubectl get pods --all-namespaces

# Verificar HPA
kubectl get hpa

# Verificar métricas
kubectl top pods
```

### Gerar Carga (Load Testing)
```bash
# O load generator já está incluído
kubectl get pod -l app=loadgenerator

# Ver logs do load generator
kubectl logs -f -l app=loadgenerator
```

### Validar Observabilidade
```bash
# Verificar métricas no Prometheus
curl http://localhost:9090/api/v1/query?query=up

# Verificar logs no Elasticsearch
curl http://localhost:9200/_cat/indices?v

# Verificar Filebeat está coletando
kubectl logs -n logging -l app=filebeat
```

## 📁 Estrutura do Projeto

```
sre-pleno-test/
├── README.md                          # Este arquivo
├── Dockerfile                         # Dockerfile otimizado (exemplo)
├── app/                               # Código da aplicação (referência)
│   └── online-boutique-ref.md        # Referência ao repo original
├── k8s/                              # Manifests Kubernetes
│   ├── 00-namespace.yaml             # Namespace da aplicação
│   ├── 01-configmap.yaml             # ConfigMaps
│   ├── 02-deployments.yaml           # Todos os Deployments
│   ├── 03-services.yaml              # Todos os Services
│   └── 04-hpa.yaml                   # Horizontal Pod Autoscalers
├── monitoring/                        # Observabilidade - Métricas
│   ├── grafana-dashboard.json        # Dashboard Grafana
│   ├── prometheus-servicemonitor.yaml # ServiceMonitor
│   └── alerting-rules.yaml           # Regras de alerta
├── ci/                               # Pipeline CI/CD
│   └── github-actions.yaml           # GitHub Actions workflow
├── elk/                              # Stack de Logging
│   ├── filebeat.yaml                 # DaemonSet Filebeat
│   ├── logstash-configmap.yaml       # Config Logstash
│   ├── logstash-deployment.yaml      # Deployment Logstash
│   ├── kibana-dashboard.json         # Dashboard Kibana
│   └── kibana-alerts.json            # Alertas Kibana
└── docs/                             # Documentação adicional
    ├── kind-config.yaml              # Config do cluster kind
    ├── architecture.md               # Arquitetura detalhada
    └── troubleshooting.md            # Guia de troubleshooting
```

## 🔧 Troubleshooting

### Pods não iniciam
```bash
# Verificar eventos
kubectl describe pod <pod-name>

# Verificar logs
kubectl logs <pod-name>

# Verificar recursos
kubectl top nodes
```

### Métricas não aparecem no Grafana
```bash
# Verificar Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Acesse: http://localhost:9090/targets

# Verificar ServiceMonitor
kubectl get servicemonitor -n monitoring
```

### Logs não chegam no Elasticsearch
```bash
# Verificar Filebeat
kubectl logs -n logging -l app=filebeat

# Verificar Logstash
kubectl logs -n logging -l app=logstash

# Verificar índices no Elasticsearch
kubectl port-forward -n logging svc/elasticsearch-master 9200:9200
curl http://localhost:9200/_cat/indices?v
```

## 📚 Referências

- [Online Boutique - Google](https://github.com/GoogleCloudPlatform/microservices-demo)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [ELK Stack Documentation](https://www.elastic.co/guide/)
- [Grafana Documentation](https://grafana.com/docs/)

## 👤 Autor

**Pablo Shizato**  
SRE Pleno Test - Janeiro 2026

## 📄 Licença

Este projeto é para fins de avaliação técnica.

---

**Status do Projeto**: ✅ Completo e Pronto para Provisionamento

