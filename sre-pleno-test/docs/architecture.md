# Arquitetura Detalhada - Online Boutique SRE

## 📐 Visão Geral da Arquitetura

Este documento descreve a arquitetura completa da solução implementada para o desafio SRE Pleno, utilizando a aplicação Online Boutique do Google como base.

## 🏗️ Componentes da Arquitetura

### 1. Camada de Aplicação (Microserviços)

```
┌─────────────────────────────────────────────────────────────────┐
│                    FRONTEND (Go)                                 │
│                    Port: 8080                                    │
└────────────┬────────────────────────────────────────────────────┘
             │
             ├──────────────────┬─────────────────┬────────────────┐
             │                  │                 │                │
┌────────────▼─────┐  ┌────────▼────────┐  ┌────▼─────┐  ┌──────▼──────┐
│  CART SERVICE    │  │ PRODUCT CATALOG │  │CURRENCY  │  │RECOMMENDATION│
│     (C#)         │  │     (Go)        │  │ (Node.js)│  │  (Python)   │
│   Port: 7070     │  │   Port: 3550    │  │Port: 7000│  │ Port: 8080  │
└────────┬─────────┘  └─────────────────┘  └──────────┘  └─────────────┘
         │
         │
┌────────▼─────────┐
│   REDIS CART     │
│   Port: 6379     │
└──────────────────┘

┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│  CHECKOUT (Go)   │  │  PAYMENT (Node)  │  │  SHIPPING (Go)   │
│  Port: 5050      │  │  Port: 50051     │  │  Port: 50051     │
└────────┬─────────┘  └──────────────────┘  └──────────────────┘
         │
         │
┌────────▼─────────┐  ┌──────────────────┐
│  EMAIL (Python)  │  │  AD SERVICE      │
│  Port: 8080      │  │  (Java)          │
└──────────────────┘  │  Port: 9555      │
                      └──────────────────┘
```

### 2. Camada de Orquestração (Kubernetes)

#### Recursos Kubernetes Implementados

| Recurso | Quantidade | Descrição |
|---------|-----------|-----------|
| Namespace | 3 | `online-boutique`, `monitoring`, `logging` |
| Deployments | 11 | Um para cada microserviço |
| Services | 12 | ClusterIP (internos) + LoadBalancer (frontend) |
| ConfigMaps | 2 | Configurações da aplicação e observabilidade |
| HPA | 10 | Autoscaling para todos os serviços principais |
| ServiceMonitor | 1 | Coleta de métricas Prometheus |
| PodMonitor | 1 | Coleta de métricas dos pods |
| PrometheusRule | 1 | Regras de alerta |

#### Estratégia de Deployment

```yaml
Deployment Strategy:
  Type: RollingUpdate
  MaxSurge: 1
  MaxUnavailable: 0
  
Health Checks:
  - Liveness Probe: HTTP/gRPC
  - Readiness Probe: HTTP/gRPC
  - Initial Delay: 10-20s
  - Period: 10s
  - Timeout: 5s
```

### 3. Camada de Observabilidade

#### 3.1 Stack de Métricas (Prometheus + Grafana)

```
┌─────────────────────────────────────────────────────────┐
│                    GRAFANA                               │
│                 Dashboards & Alerting                    │
│                    Port: 3000                            │
└────────────────────────┬────────────────────────────────┘
                         │
                         │ Query
                         │
┌────────────────────────▼────────────────────────────────┐
│                   PROMETHEUS                             │
│              Metrics Storage & Query                     │
│                    Port: 9090                            │
└────────────────────────┬────────────────────────────────┘
                         │
                         │ Scrape (30s interval)
                         │
┌────────────────────────▼────────────────────────────────┐
│              ServiceMonitor / PodMonitor                 │
│          Automatic Service Discovery                     │
└────────────────────────┬────────────────────────────────┘
                         │
                         │
┌────────────────────────▼────────────────────────────────┐
│            Application Pods (/metrics)                   │
│    frontend, cart, product, currency, etc.              │
└─────────────────────────────────────────────────────────┘
```

**Métricas Coletadas:**
- Request rate (req/s)
- Request latency (P50, P95, P99)
- Error rate (%)
- CPU usage (cores)
- Memory usage (bytes)
- Pod restarts
- HPA metrics

#### 3.2 Stack de Logs (ELK)

```
┌─────────────────────────────────────────────────────────┐
│                      KIBANA                              │
│            Visualization & Dashboards                    │
│                    Port: 5601                            │
└────────────────────────┬────────────────────────────────┘
                         │
                         │ Query
                         │
┌────────────────────────▼────────────────────────────────┐
│                  ELASTICSEARCH                           │
│              Indexed Log Storage                         │
│                    Port: 9200                            │
│         Index: app-logs-staging-YYYY.MM.DD              │
└────────────────────────▲────────────────────────────────┘
                         │
                         │ Bulk Insert
                         │
┌────────────────────────┴────────────────────────────────┐
│                    LOGSTASH                              │
│          Log Parsing & Enrichment                        │
│                    Port: 5044                            │
│  Pipeline: Parse → Filter → Transform → Output          │
└────────────────────────▲────────────────────────────────┘
                         │
                         │ Beats Protocol
                         │
┌────────────────────────┴────────────────────────────────┐
│              FILEBEAT (DaemonSet)                        │
│            Log Collection from Nodes                     │
│   Reads: /var/log/containers/*.log                      │
└────────────────────────▲────────────────────────────────┘
                         │
                         │ Container Logs
                         │
┌────────────────────────┴────────────────────────────────┐
│                  Kubernetes Nodes                        │
│              Container Runtime Logs                      │
└─────────────────────────────────────────────────────────┘
```

**Campos Extraídos pelo Logstash:**
- `@timestamp`: Timestamp do log
- `log_level`: INFO/WARN/ERROR
- `service_name`: Nome do microserviço
- `namespace`: Namespace Kubernetes
- `pod_name`: Nome do pod
- `endpoint`: Endpoint HTTP acessado
- `latency_ms`: Latência da requisição
- `environment`: staging/production

### 4. Camada de CI/CD (GitHub Actions)

```
┌─────────────────────────────────────────────────────────┐
│                   GitHub Repository                      │
│                    (Source Code)                         │
└────────────────────────┬────────────────────────────────┘
                         │
                         │ Push/PR Trigger
                         │
┌────────────────────────▼────────────────────────────────┐
│                  GitHub Actions                          │
│                                                          │
│  Stage 1: Lint                                          │
│    ├─ Hadolint (Dockerfile)                            │
│    ├─ Kubeval (K8s manifests)                          │
│    └─ YAML Lint                                        │
│                                                          │
│  Stage 2: Security                                      │
│    ├─ Trivy (Vulnerability scan)                       │
│    └─ Checkov (IaC security)                           │
│                                                          │
│  Stage 3: Build                                         │
│    ├─ Docker Build (multi-stage)                       │
│    ├─ Tag images                                       │
│    └─ Push to registry                                 │
│                                                          │
│  Stage 4: Test                                          │
│    ├─ Deploy to Kind cluster                           │
│    ├─ Smoke tests                                      │
│    └─ Integration tests                                │
│                                                          │
│  Stage 5: Deploy                                        │
│    ├─ Apply K8s manifests                              │
│    ├─ Update image tags                                │
│    ├─ Wait for rollout                                 │
│    └─ Health checks                                    │
│                                                          │
│  Stage 6: Observability                                 │
│    ├─ Deploy Prometheus                                │
│    ├─ Deploy ELK                                       │
│    └─ Import dashboards                                │
│                                                          │
│  Stage 7: Notify                                        │
│    └─ Slack notification                               │
└─────────────────────────────────────────────────────────┘
```

## 🔐 Segurança

### Implementações de Segurança

1. **Container Security**
   - Usuário não-root em todos os containers
   - SecurityContext configurado
   - Imagens base oficiais e atualizadas
   - Scan de vulnerabilidades com Trivy

2. **Network Security**
   - Services ClusterIP para comunicação interna
   - LoadBalancer apenas para frontend
   - NetworkPolicies (opcional)

3. **RBAC**
   - ServiceAccounts específicos
   - ClusterRoles com least privilege
   - ClusterRoleBindings limitados

4. **Secrets Management**
   - Secrets do Kubernetes para credenciais
   - Não há hardcoded secrets no código

## 📊 SLIs e SLOs

### Service Level Indicators (SLIs)

| SLI | Métrica | Cálculo |
|-----|---------|---------|
| Availability | Success Rate | `(total_requests - 5xx_errors) / total_requests` |
| Latency P95 | Response Time | `histogram_quantile(0.95, request_duration)` |
| Latency P99 | Response Time | `histogram_quantile(0.99, request_duration)` |
| Error Rate | Error % | `5xx_errors / total_requests * 100` |

### Service Level Objectives (SLOs)

| SLO | Target | Measurement Window |
|-----|--------|-------------------|
| Availability | 99.9% | 30 dias |
| Latency P95 | < 1s | 5 minutos |
| Latency P99 | < 2s | 5 minutos |
| Error Rate | < 1% | 5 minutos |

## 🚨 Alerting Strategy

### Níveis de Severidade

1. **Critical** (P1)
   - Service Down
   - SLO Breach
   - High Error Rate (> 5%)
   - Pod Crash Loop

2. **Warning** (P2)
   - High Latency
   - High Resource Usage (> 90%)
   - HPA Maxed Out

3. **Info** (P3)
   - Low Traffic
   - Deployment Events

### Canais de Notificação

- **Slack**: Alertas em tempo real
- **Email**: Resumo diário
- **PagerDuty**: Alertas críticos (P1)

## 🔄 Disaster Recovery

### Backup Strategy

1. **Configurações**
   - Todos os manifests versionados no Git
   - ConfigMaps e Secrets documentados

2. **Dados**
   - Redis: Snapshot periódico
   - Elasticsearch: Snapshot para S3

### Rollback Plan

```bash
# Rollback de deployment
kubectl rollout undo deployment/<name> -n online-boutique

# Rollback para versão específica
kubectl rollout undo deployment/<name> --to-revision=<n> -n online-boutique

# Verificar histórico
kubectl rollout history deployment/<name> -n online-boutique
```

## 📈 Capacity Planning

### Recursos Atuais

| Serviço | CPU Request | CPU Limit | Memory Request | Memory Limit | Replicas |
|---------|-------------|-----------|----------------|--------------|----------|
| Frontend | 100m | 200m | 64Mi | 128Mi | 2-10 (HPA) |
| Cart | 200m | 300m | 64Mi | 128Mi | 2-8 (HPA) |
| Product | 100m | 200m | 64Mi | 128Mi | 2-8 (HPA) |

### Scaling Triggers

- **CPU**: > 70%
- **Memory**: > 75%
- **Custom Metrics**: Request rate, latency

## 🎯 Performance Benchmarks

### Expected Performance

- **Throughput**: 1000 req/s
- **Latency P95**: < 500ms
- **Latency P99**: < 1s
- **Error Rate**: < 0.1%

### Load Testing

```bash
# Usando k6
k6 run --vus 100 --duration 5m tests/load-test.js

# Usando Apache Bench
ab -n 10000 -c 100 http://frontend:8080/
```

## 📚 Referências

- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [Prometheus Operator](https://prometheus-operator.dev/)
- [ELK Stack Documentation](https://www.elastic.co/guide/)
- [Google SRE Book](https://sre.google/books/)
- [Online Boutique Architecture](https://github.com/GoogleCloudPlatform/microservices-demo)

---

**Última Atualização**: Janeiro 2026  
**Versão**: 1.0.0  
**Autor**: Pablo Shizato - SRE Pleno Test

