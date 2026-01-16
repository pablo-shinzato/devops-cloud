# 🚀 Quick Start Guide - SRE Pleno Test

## ⚡ Setup Rápido (5 minutos)

### Pré-requisitos

Certifique-se de ter instalado:

```bash
# Verificar instalações
docker --version      # Docker 20.10+
kubectl version       # kubectl 1.24+
kind version          # kind 0.20+
helm version          # Helm 3.10+
```

### Instalação dos Pré-requisitos

#### macOS (usando Homebrew)

```bash
brew install docker kubectl kind helm
```

#### Linux (Ubuntu/Debian)

```bash
# Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

---

## 🎯 Opção 1: Setup Automático com Makefile (Recomendado)

```bash
# 1. Clone ou navegue até o diretório do projeto
cd sre-pleno-test

# 2. Execute o quickstart (faz tudo automaticamente)
make quickstart

# Isso irá:
# - Criar cluster Kind
# - Instalar Metrics Server
# - Deploy da aplicação Online Boutique
# - Deploy do stack de observabilidade (Prometheus, Grafana, ELK)
# - Configurar todos os recursos necessários
```

**Tempo estimado**: 10-15 minutos

---

## 🛠️ Opção 2: Setup Manual Passo a Passo

### Passo 1: Provisionar Cluster

```bash
# Usando script
./scripts/setup-cluster.sh

# OU usando Makefile
make setup
```

### Passo 2: Deploy da Aplicação

```bash
# Usando script
./scripts/deploy-app.sh

# OU usando Makefile
make deploy-app
```

### Passo 3: Deploy Observabilidade

```bash
# Usando script
./scripts/deploy-observability.sh

# OU usando Makefile
make deploy-observability
```

---

## ✅ Verificar Status

```bash
# Verificar todos os recursos
make status

# OU manualmente
kubectl get pods --all-namespaces
kubectl get svc --all-namespaces
kubectl get hpa -n online-boutique
```

**Saída esperada**: Todos os pods em status `Running`

---

## 🌐 Acessar a Aplicação

### Aplicação Online Boutique

```bash
# Port forward
make port-forward-app

# OU manualmente
kubectl port-forward -n online-boutique svc/frontend-external 8080:80
```

**Acesse**: http://localhost:8080

### Grafana (Dashboards de Métricas)

```bash
# Port forward
make port-forward-grafana

# OU manualmente
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

**Acesse**: http://localhost:3000
- **Usuário**: `admin`
- **Senha**: Execute `kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode`

### Prometheus (Métricas Raw)

```bash
# Port forward
make port-forward-prometheus

# OU manualmente
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

**Acesse**: http://localhost:9090

### Kibana (Logs)

```bash
# Port forward
make port-forward-kibana

# OU manualmente
kubectl port-forward -n logging svc/kibana-kibana 5601:5601
```

**Acesse**: http://localhost:5601

---

## 📊 Importar Dashboards

### Grafana Dashboard

1. Acesse Grafana: http://localhost:3000
2. Login com `admin` / senha obtida acima
3. Menu lateral: **Dashboards** → **Import**
4. Click em **Upload JSON file**
5. Selecione: `monitoring/grafana-dashboard.json`
6. Click em **Import**

### Kibana Dashboard

1. Acesse Kibana: http://localhost:5601
2. Menu lateral: **Stack Management** → **Saved Objects**
3. Click em **Import**
4. Selecione: `elk/kibana-dashboard.json`
5. Click em **Import**

### Configurar Index Pattern no Kibana

1. Menu lateral: **Stack Management** → **Index Patterns**
2. Click em **Create index pattern**
3. Index pattern name: `app-logs-staging-*`
4. Time field: `@timestamp`
5. Click em **Create index pattern**

---

## 🧪 Executar Testes

### Smoke Test

```bash
make test
```

### Load Test (requer k6)

```bash
# Instalar k6
brew install k6  # macOS
# ou veja: https://k6.io/docs/getting-started/installation/

# Executar teste de carga
k6 run tests/load-test.js

# Teste customizado
k6 run --vus 50 --duration 2m tests/load-test.js
```

---

## 📈 Monitorar a Aplicação

### Ver Logs em Tempo Real

```bash
# Logs do frontend
make logs

# Logs de todos os pods
make logs-all

# Logs de um serviço específico
kubectl logs -n online-boutique -l app=cartservice -f
```

### Ver Métricas de Recursos

```bash
# CPU e Memory
make top

# OU manualmente
kubectl top nodes
kubectl top pods -n online-boutique
```

### Ver Eventos

```bash
make events

# OU manualmente
kubectl get events -n online-boutique --sort-by='.lastTimestamp'
```

---

## 🔧 Operações Comuns

### Escalar Aplicação

```bash
# Escalar para 5 réplicas
make scale-up

# Escalar para 2 réplicas
make scale-down

# Escalar manualmente
kubectl scale deployment frontend -n online-boutique --replicas=3
```

### Reiniciar Aplicação

```bash
make restart

# OU manualmente
kubectl rollout restart deployment -n online-boutique
```

### Fazer Rollback

```bash
make rollback

# OU manualmente
kubectl rollout undo deployment/frontend -n online-boutique
```

---

## 🐛 Troubleshooting

### Pods não iniciam

```bash
# Ver detalhes do pod
kubectl describe pod <pod-name> -n online-boutique

# Ver logs
kubectl logs <pod-name> -n online-boutique

# Ver eventos
kubectl get events -n online-boutique
```

### Métricas não aparecem

```bash
# Verificar Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Acesse: http://localhost:9090/targets

# Verificar ServiceMonitors
kubectl get servicemonitor -n monitoring
```

### Logs não chegam no Elasticsearch

```bash
# Verificar Filebeat
kubectl logs -n logging -l app=filebeat

# Verificar Logstash
kubectl logs -n logging -l app=logstash

# Verificar índices
kubectl port-forward -n logging svc/elasticsearch-master 9200:9200
curl http://localhost:9200/_cat/indices?v
```

**Guia completo**: Ver `docs/troubleshooting.md`

---

## 🧹 Limpar Ambiente

```bash
# Remover tudo
make clean

# OU manualmente
./scripts/cleanup.sh
```

---

## 📚 Próximos Passos

1. **Explorar Dashboards**
   - Grafana: Métricas de performance
   - Kibana: Análise de logs

2. **Testar Alertas**
   - Gerar carga alta
   - Verificar alertas no Grafana

3. **Experimentar Scaling**
   - Testar HPA com carga
   - Ver pods escalando automaticamente

4. **Analisar Logs**
   - Buscar por erros no Kibana
   - Analisar latências

5. **Customizar**
   - Ajustar limites de recursos
   - Modificar thresholds do HPA
   - Adicionar novos alertas

---

## 📞 Ajuda

### Comandos Úteis

```bash
# Ver todos os comandos disponíveis
make help

# Ver informações do ambiente
make info

# Ver versões das ferramentas
make version
```

### Documentação

- **README.md**: Documentação completa
- **docs/architecture.md**: Arquitetura detalhada
- **docs/troubleshooting.md**: Guia de troubleshooting
- **QUICKSTART.md**: Este guia

### Recursos Online

- [Kubernetes Docs](https://kubernetes.io/docs/)
- [Prometheus Docs](https://prometheus.io/docs/)
- [Grafana Docs](https://grafana.com/docs/)
- [ELK Stack Docs](https://www.elastic.co/guide/)
- [Online Boutique](https://github.com/GoogleCloudPlatform/microservices-demo)

---

## ✨ Dicas

1. **Use o Makefile**: Todos os comandos comuns estão disponíveis via `make`
2. **Port Forwards**: Mantenha terminais separados para cada port forward
3. **Logs**: Use `make logs` para ver logs em tempo real
4. **Status**: Execute `make status` frequentemente para monitorar
5. **Dashboards**: Importe os dashboards JSON para melhor visualização

---

**Pronto!** 🎉 Você agora tem um ambiente SRE completo rodando localmente!

Para dúvidas ou problemas, consulte `docs/troubleshooting.md` ou execute `make help`.

