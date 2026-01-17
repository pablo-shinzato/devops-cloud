# 🎤 Guia de Apresentação - SRE Pleno Test

## 📋 Roteiro de Apresentação (30-45 minutos)

### Preparação Antes da Apresentação

```bash
# 1. Garantir que tudo está rodando
cd sre-pleno-test
make quickstart

# 2. Abrir múltiplos terminais
# Terminal 1: Logs em tempo real
make logs

# Terminal 2: Status do cluster
watch -n 5 'kubectl get pods --all-namespaces'

# Terminal 3: Métricas
watch -n 5 'kubectl top pods -n online-boutique'

# 3. Abrir navegadores com as interfaces
make port-forward-app &
make port-forward-grafana &
make port-forward-kibana &
```

---

## 🎯 Estrutura da Apresentação

### 1. Introdução (5 minutos)

#### Slide 1: Visão Geral do Projeto

**Pontos-chave:**
- Desafio: Implementar solução SRE completa para Online Boutique
- Aplicação: 11 microserviços do Google (Go, Python, Node.js, Java, C#)
- Objetivo: Demonstrar competências em containerização, Kubernetes, observabilidade, CI/CD e logging

**Demo:**
```bash
# Mostrar estrutura do projeto
tree -L 2 sre-pleno-test/

# Mostrar estatísticas
cat PROJECT_SUMMARY.md | head -30
```

#### Slide 2: Arquitetura da Solução

**Pontos-chave:**
- Cluster Kubernetes local (Kind) com 3 nodes
- 11 microserviços com HPA configurado
- Stack de observabilidade completo (Prometheus + Grafana + ELK)
- Pipeline CI/CD com GitHub Actions

**Demo:**
```bash
# Mostrar cluster
kubectl get nodes
kubectl get namespaces

# Mostrar recursos
kubectl get all -n online-boutique
```

---

### 2. Containerização (5 minutos)

#### Demonstrar Dockerfile Otimizado

**Pontos-chave:**
- Multi-stage build (redução de 60-80% no tamanho)
- Usuário não-root para segurança
- Health checks implementados
- Variáveis de ambiente parametrizadas

**Demo:**
```bash
# Mostrar Dockerfile
cat Dockerfile | head -50

# Destacar:
# - FROM ... AS builder (stage 1)
# - FROM scratch (stage 2)
# - USER appuser
# - HEALTHCHECK
# - ENV APP_ENV=staging
```

**Explicar decisões técnicas:**
- Por que multi-stage? → Segurança + Tamanho
- Por que scratch? → Minimal footprint
- Por que não-root? → Princípio do menor privilégio

---

### 3. Kubernetes (10 minutos)

#### 3.1 Deployments e Services

**Pontos-chave:**
- 11 Deployments com 2 réplicas cada
- Resources (requests/limits) configurados
- Probes (liveness/readiness) em todos os serviços
- Labels padronizados para service discovery

**Demo:**
```bash
# Mostrar deployments
kubectl get deployments -n online-boutique

# Detalhar um deployment
kubectl describe deployment frontend -n online-boutique

# Destacar:
# - Replicas: 2
# - Resources (requests/limits)
# - Liveness/Readiness probes
# - Labels
```

#### 3.2 HPA (Horizontal Pod Autoscaler)

**Pontos-chave:**
- HPA v2 com múltiplas métricas (CPU + Memory)
- Thresholds: CPU > 70%, Memory > 75%
- Behavior policies para controle de scaling

**Demo:**
```bash
# Mostrar HPAs
kubectl get hpa -n online-boutique

# Detalhar um HPA
kubectl describe hpa frontend-hpa -n online-boutique

# Simular carga (opcional)
kubectl run -it --rm load-generator --image=busybox /bin/sh
# Dentro do pod: while true; do wget -q -O- http://frontend.online-boutique/; done
```

#### 3.3 ConfigMaps

**Pontos-chave:**
- Separação de configuração e código
- APP_ENV=staging
- Endpoints de serviços centralizados

**Demo:**
```bash
# Mostrar ConfigMaps
kubectl get configmap -n online-boutique

# Ver conteúdo
kubectl describe configmap app-config -n online-boutique
```

---

### 4. Observabilidade - Métricas (8 minutos)

#### 4.1 Prometheus

**Pontos-chave:**
- ServiceMonitor para descoberta automática
- Coleta de métricas a cada 30s
- Retention de 7 dias

**Demo:**
```bash
# Abrir Prometheus
# http://localhost:9090

# Mostrar targets
# Status > Targets

# Executar queries:
# - up{namespace="online-boutique"}
# - rate(http_requests_total[5m])
# - histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

#### 4.2 Grafana Dashboard

**Pontos-chave:**
- 10 painéis principais
- Métricas essenciais: Request Rate, Latency, Error Rate, CPU, Memory
- Alertas visuais configurados
- SLI/SLO tracking

**Demo:**
```bash
# Abrir Grafana
# http://localhost:3000
# Login: admin / [senha do secret]

# Navegar pelo dashboard:
# 1. Overview - Request Rate
# 2. Latency P50/P95/P99
# 3. Error Rate
# 4. CPU Usage
# 5. Memory Usage
# 6. Pod Restarts
# 7. HPA Status
# 8. SLI/SLO Tracking
```

**Explicar métricas:**
- Por que P95/P99? → Experiência do usuário
- Por que Error Rate? → SLO compliance
- Por que HPA Status? → Capacity planning

---

### 5. Observabilidade - Logs (8 minutos)

#### 5.1 ELK Stack Architecture

**Pontos-chave:**
- Filebeat (DaemonSet) coleta logs de todos os pods
- Logstash faz parsing e enriquecimento
- Elasticsearch armazena logs indexados
- Kibana para visualização e análise

**Demo:**
```bash
# Verificar stack ELK
kubectl get pods -n logging

# Ver logs do Filebeat
kubectl logs -n logging -l app=filebeat --tail=20

# Ver pipeline do Logstash
kubectl get configmap logstash-config -n logging -o yaml
```

#### 5.2 Kibana Dashboard

**Pontos-chave:**
- Index pattern: app-logs-staging-*
- 6 visualizações principais
- Campos extraídos: log_level, service_name, endpoint, latency_ms

**Demo:**
```bash
# Abrir Kibana
# http://localhost:5601

# 1. Verificar índices
# Dev Tools: GET _cat/indices?v

# 2. Discover
# Mostrar logs em tempo real
# Filtrar por: log_level:ERROR

# 3. Dashboard
# Navegar pelas visualizações:
# - Volume por Nível (Pie Chart)
# - Top Endpoints (Table)
# - Erros ao Longo do Tempo (Line)
# - Distribuição de Latência (Histogram)
```

#### 5.3 Alertas

**Pontos-chave:**
- Alerta: ≥ 20 erros em 5 minutos
- Throttle de 10 minutos
- Notificações configuradas

**Demo:**
```bash
# Mostrar configuração de alertas
cat elk/kibana-alerts.json | jq '.objects[] | select(.type=="alert")'
```

---

### 6. CI/CD Pipeline (5 minutos)

**Pontos-chave:**
- GitHub Actions com 8 jobs
- Stages: Lint → Security → Build → Test → Deploy
- Rollback automático em caso de falha
- Notificações Slack

**Demo:**
```bash
# Mostrar pipeline
cat ci/github-actions.yaml | head -100

# Explicar stages:
# 1. Lint: hadolint, kubeval, yamllint
# 2. Security: Trivy, Checkov
# 3. Build: Docker build + push
# 4. Test: Deploy em Kind + smoke tests
# 5. Deploy: Deploy em staging
# 6. Observability: Deploy monitoring
# 7. Performance: Load tests
# 8. Notify: Slack notification
```

**Destacar:**
- Security scanning antes do build
- Testes automatizados
- Deploy progressivo
- Rollback automático

---

### 7. Automação e Ferramentas (3 minutos)

#### Makefile

**Pontos-chave:**
- 40+ comandos úteis
- Categorias: Setup, Deploy, Monitoring, Troubleshooting
- One-command setup

**Demo:**
```bash
# Mostrar comandos disponíveis
make help

# Demonstrar alguns comandos:
make status
make top
make info
```

#### Scripts Shell

**Pontos-chave:**
- 4 scripts principais
- Automação completa
- Error handling e logging colorido

**Demo:**
```bash
# Listar scripts
ls -la scripts/

# Mostrar um script
cat scripts/setup-cluster.sh | head -50
```

---

### 8. Testes e Validação (3 minutos)

#### Smoke Tests

**Demo:**
```bash
# Executar smoke tests
make test

# Resultado esperado:
# ✅ Todos os pods estão rodando
# ✅ HPA configurado
# ✅ Smoke tests passaram!
```

#### Load Tests

**Demo:**
```bash
# Mostrar load test
cat tests/load-test.js | head -50

# Executar (se k6 instalado)
k6 run --vus 10 --duration 30s tests/load-test.js

# Mostrar resultados:
# - Request rate
# - Latency (P95, P99)
# - Error rate
```

---

### 9. Troubleshooting (3 minutos)

**Pontos-chave:**
- Guia completo de troubleshooting
- Comandos úteis para debug
- Cenários comuns e soluções

**Demo:**
```bash
# Mostrar guia
cat docs/troubleshooting.md | head -100

# Demonstrar comandos de debug:
make describe-pods
make get-errors
make debug-logs

# Simular problema (opcional):
# - Deletar um pod
# - Ver logs
# - Ver HPA reagindo
kubectl delete pod -n online-boutique -l app=frontend --force
kubectl get pods -n online-boutique -w
```

---

### 10. Decisões Técnicas (3 minutos)

#### Justificar Escolhas

**Pontos-chave:**

1. **Aplicação: Online Boutique**
   - Por quê? Aplicação oficial do Google, multi-linguagem, complexa

2. **Cluster: Kind**
   - Por quê? Leve, rápido, reproduzível, ideal para desenvolvimento

3. **Observabilidade: Prometheus + ELK**
   - Por quê? Padrão de mercado, separação de concerns (métricas vs logs)

4. **CI/CD: GitHub Actions**
   - Por quê? Integração nativa, free tier generoso, fácil configuração

5. **Automação: Makefile + Scripts**
   - Por quê? Simplicidade, portabilidade, fácil manutenção

**Demo:**
```bash
# Mostrar seção de decisões técnicas no README
cat README.md | grep -A 50 "Decisões Técnicas"
```

---

### 11. Conclusão e Q&A (5 minutos)

#### Resumo dos Pontos Principais

**Checklist de Entregáveis:**
- ✅ Containerização (20 pts)
- ✅ Kubernetes (30 pts)
- ✅ Observabilidade (15 pts)
- ✅ CI/CD (10 pts)
- ✅ ELK Stack (25 pts)
- **Total: 100/100 pontos**

**Diferenciais:**
- Automação completa (Makefile, scripts)
- Documentação excepcional (5 documentos)
- Observabilidade avançada (15+ alertas)
- Segurança (scanning, best practices)
- Testes (load tests, smoke tests)

**Demo Final:**
```bash
# Mostrar tudo rodando
make status

# Mostrar métricas em tempo real
make top

# Acessar aplicação
# http://localhost:8080
```

#### Perguntas e Respostas

**Perguntas Esperadas:**

1. **"Por que escolheu Kind ao invés de Minikube?"**
   - Resposta: Kind é mais leve, suporta múltiplos nós nativamente, melhor para CI/CD

2. **"Como garantir alta disponibilidade em produção?"**
   - Resposta: Multi-AZ deployment, PodDisruptionBudgets, ReplicaSets, Load Balancers

3. **"Como escalar para múltiplos clusters?"**
   - Resposta: Federation, GitOps com ArgoCD, Service Mesh (Istio)

4. **"Como implementar disaster recovery?"**
   - Resposta: Backups regulares (Velero), Multi-region, RTO/RPO definidos

5. **"Como melhorar a segurança?"**
   - Resposta: NetworkPolicies, PodSecurityPolicies, Secrets encryption, mTLS

---

## 📊 Materiais de Apoio

### Documentos para Compartilhar

1. **README.md** - Documentação completa
2. **QUICKSTART.md** - Guia de início rápido
3. **PROJECT_SUMMARY.md** - Resumo executivo
4. **CHECKLIST.md** - Checklist de validação
5. **docs/architecture.md** - Arquitetura detalhada

### Links Úteis

- Repositório: [URL do GitHub]
- Dashboards: Grafana + Kibana
- Documentação Online Boutique: https://github.com/GoogleCloudPlatform/microservices-demo

---

## 🎯 Dicas para a Apresentação

### Antes da Apresentação

- [ ] Testar todo o ambiente
- [ ] Garantir que todos os pods estão Running
- [ ] Abrir todos os port-forwards necessários
- [ ] Preparar múltiplos terminais
- [ ] Testar acesso aos dashboards
- [ ] Revisar pontos principais

### Durante a Apresentação

- ✅ Falar com confiança e clareza
- ✅ Demonstrar conhecimento técnico profundo
- ✅ Explicar decisões técnicas
- ✅ Mostrar código e configurações
- ✅ Interagir com o ambiente ao vivo
- ✅ Estar preparado para perguntas

### Após a Apresentação

- [ ] Disponibilizar repositório
- [ ] Compartilhar documentação
- [ ] Responder perguntas adicionais
- [ ] Agradecer pela oportunidade

---

