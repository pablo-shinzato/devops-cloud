# Guia de Troubleshooting - Online Boutique SRE

## 🔍 Índice de Problemas Comuns

1. [Cluster Kind não inicia (kubelet error)](#cluster-kind-não-inicia-kubelet-error)
2. [Pods não iniciam](#pods-não-iniciam)
3. [Métricas não aparecem no Grafana](#métricas-não-aparecem-no-grafana)
4. [Logs não chegam no Elasticsearch](#logs-não-chegam-no-elasticsearch)
5. [Alta latência](#alta-latência)
6. [Erros 5xx](#erros-5xx)
7. [HPA não está escalando](#hpa-não-está-escalando)
8. [OOMKilled](#oomkilled)
9. [CrashLoopBackOff](#crashloopbackoff)

---

## Cluster Kind não inicia (kubelet error)

### Sintomas
```
ERROR: failed to create cluster: failed to init node with kubeadm
[kubelet-check] It seems like the kubelet isn't running or healthy.
[kubelet-check] The HTTP call equal to 'curl -sSL http://localhost:10248/healthz' failed with error: Get "http://localhost:10248/healthz": dial tcp [::1]:10248: connect: connection refused.
```

### Diagnóstico

```bash
# 1. Verificar se Docker está rodando
docker info

# 2. Verificar recursos do Docker
docker system df
docker stats --no-stream

# 3. Verificar versão do Kind
kind version

# 4. Verificar logs do container do control plane (se existir)
docker ps -a | grep sre-pleno
docker logs <container-id> --tail 100
```

### Soluções

#### 1. Limpar clusters parciais

```bash
# Deletar cluster existente
kind delete cluster --name sre-pleno

# Limpar containers órfãos
docker ps -a --filter "name=sre-pleno" --format "{{.ID}}" | xargs docker rm -f

# Limpar imagens antigas
docker image prune -f
```

#### 2. Verificar recursos do sistema

O Kind precisa de recursos suficientes:
- **Mínimo**: 2 CPUs, 4GB RAM
- **Recomendado**: 4 CPUs, 8GB RAM

```bash
# Verificar recursos disponíveis
docker info | grep -i memory
docker info | grep -i cpu

# Aumentar recursos do Docker (se necessário)
# Docker Desktop: Settings > Resources
```

#### 3. Problemas com cgroups

Se o sistema usa cgroups v2, pode ser necessário ajustar:

```bash
# Verificar versão de cgroups
stat -fc %T /sys/fs/cgroup/

# Se retornar "cgroup2fs", o sistema usa cgroups v2
# A configuração já está ajustada no kind-config.yaml
```

#### 4. Conflitos de portas

```bash
# Verificar se as portas estão em uso
netstat -tuln | grep -E ':(6443|80|443|30000|30001)'

# Ou usar lsof
lsof -i :6443
lsof -i :80
```

#### 5. Reinstalar com configuração atualizada

```bash
# Garantir que está usando a configuração atualizada
cat docs/kind-config.yaml | grep cgroup-driver

# Recriar cluster
make clean  # ou: kind delete cluster --name sre-pleno
make setup
```

#### 6. Usar versão alternativa do Kubernetes

Se o problema persistir, tente uma versão mais recente:

```bash
# Editar docs/kind-config.yaml
# Alterar: image: kindest/node:v1.28.0
# Para: image: kindest/node:v1.29.0
# Ou: image: kindest/node:v1.27.3
```

#### 7. Verificar logs detalhados

```bash
# Criar cluster com mais verbosidade
kind create cluster \
  --name sre-pleno \
  --config docs/kind-config.yaml \
  --verbosity 9 \
  --wait 10m
```

### Solução Rápida

```bash
# 1. Limpar tudo
kind delete cluster --name sre-pleno 2>/dev/null || true
docker system prune -f

# 2. Verificar Docker
docker info

# 3. Recriar com configuração atualizada
make setup
```

---

## Pods não iniciam

### Sintomas
```bash
$ kubectl get pods -n online-boutique
NAME                          READY   STATUS    RESTARTS   AGE
frontend-7d8f9c8b9d-abc12     0/1     Pending   0          5m
```

### Diagnóstico

```bash
# 1. Verificar eventos do pod
kubectl describe pod <pod-name> -n online-boutique

# 2. Verificar recursos disponíveis no cluster
kubectl top nodes

# 3. Verificar se há problemas com PVC
kubectl get pvc -n online-boutique

# 4. Verificar logs do scheduler
kubectl logs -n kube-system -l component=kube-scheduler
```

### Causas Comuns

#### 1. Recursos Insuficientes
```
Error: 0/3 nodes are available: 3 Insufficient cpu.
```

**Solução:**
```bash
# Aumentar recursos do cluster ou reduzir requests
kubectl edit deployment <deployment-name> -n online-boutique

# Reduzir requests temporariamente
spec:
  containers:
  - resources:
      requests:
        cpu: 50m  # Era 100m
        memory: 32Mi  # Era 64Mi
```

#### 2. ImagePullBackOff
```
Error: Failed to pull image "gcr.io/invalid/image:tag"
```

**Solução:**
```bash
# Verificar se a imagem existe
docker pull gcr.io/google-samples/microservices-demo/frontend:v0.8.0

# Corrigir no deployment
kubectl set image deployment/frontend frontend=gcr.io/google-samples/microservices-demo/frontend:v0.8.0 -n online-boutique
```

#### 3. Node Affinity/Taints
```
Error: 0/3 nodes are available: 3 node(s) had taint {key: value}
```

**Solução:**
```bash
# Remover taint
kubectl taint nodes <node-name> key:NoSchedule-

# Ou adicionar toleration no pod
spec:
  tolerations:
  - key: "key"
    operator: "Equal"
    value: "value"
    effect: "NoSchedule"
```

---

## Métricas não aparecem no Grafana

### Sintomas
- Dashboard vazio ou "No data"
- Queries retornam vazio

### Diagnóstico

```bash
# 1. Verificar se Prometheus está rodando
kubectl get pods -n monitoring -l app=prometheus

# 2. Verificar targets do Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Acessar: http://localhost:9090/targets

# 3. Verificar ServiceMonitors
kubectl get servicemonitor -n monitoring

# 4. Verificar se os pods têm as annotations corretas
kubectl get pods -n online-boutique -o yaml | grep -A 5 annotations
```

### Soluções

#### 1. ServiceMonitor não está selecionando os services

```bash
# Verificar labels dos services
kubectl get svc -n online-boutique --show-labels

# Verificar selector do ServiceMonitor
kubectl get servicemonitor online-boutique-metrics -n monitoring -o yaml
```

**Correção:**
```yaml
# Adicionar label nos services
kubectl label svc frontend -n online-boutique environment=staging

# Ou ajustar ServiceMonitor
spec:
  selector:
    matchLabels:
      environment: staging  # Deve corresponder aos services
```

#### 2. Endpoint /metrics não existe

```bash
# Testar endpoint diretamente
kubectl port-forward -n online-boutique svc/frontend 8080:80
curl http://localhost:8080/metrics
```

**Se retornar 404:**
- A aplicação Online Boutique original pode não expor métricas
- Considere adicionar um sidecar exporter

#### 3. Prometheus não tem permissão

```bash
# Verificar RBAC
kubectl get clusterrole prometheus-kube-prometheus-prometheus -o yaml
kubectl get clusterrolebinding prometheus-kube-prometheus-prometheus -o yaml
```

---

## Logs não chegam no Elasticsearch

### Sintomas
- Kibana não mostra logs
- Índices vazios ou não criados

### Diagnóstico

```bash
# 1. Verificar Filebeat está rodando
kubectl get pods -n logging -l app=filebeat

# 2. Verificar logs do Filebeat
kubectl logs -n logging -l app=filebeat --tail=100

# 3. Verificar Logstash está recebendo
kubectl logs -n logging -l app=logstash --tail=100

# 4. Verificar índices no Elasticsearch
kubectl port-forward -n logging svc/elasticsearch-master 9200:9200
curl http://localhost:9200/_cat/indices?v
```

### Soluções

#### 1. Filebeat não consegue ler logs

```bash
# Verificar permissões
kubectl describe daemonset filebeat -n logging

# Verificar volumes montados
kubectl get daemonset filebeat -n logging -o yaml | grep -A 10 volumeMounts
```

**Correção:**
```yaml
# Garantir que o volume está montado corretamente
volumeMounts:
- name: varlog
  mountPath: /var/log
  readOnly: true
- name: varlibdockercontainers
  mountPath: /var/lib/docker/containers
  readOnly: true
```

#### 2. Logstash não está processando

```bash
# Verificar pipeline do Logstash
kubectl logs -n logging -l app=logstash | grep -i error

# Testar parsing manualmente
kubectl exec -it -n logging <logstash-pod> -- /bin/bash
# Dentro do pod:
cat /usr/share/logstash/pipeline/logstash.conf
```

**Correção comum - Grok pattern inválido:**
```ruby
# Simplificar pattern
filter {
  grok {
    match => { "message" => "%{GREEDYDATA:log_message}" }
    tag_on_failure => ["_grokparsefailure"]
  }
}
```

#### 3. Elasticsearch está indisponível

```bash
# Verificar health do Elasticsearch
curl http://localhost:9200/_cluster/health?pretty

# Verificar recursos
kubectl top pods -n logging -l app=elasticsearch
```

**Se cluster está RED:**
```bash
# Verificar shards
curl http://localhost:9200/_cat/shards?v

# Realocar shards não atribuídos
curl -X POST "http://localhost:9200/_cluster/reroute?retry_failed=true"
```

---

## Alta Latência

### Sintomas
- P95 > 1s
- P99 > 2s
- Usuários reportando lentidão

### Diagnóstico

```bash
# 1. Verificar métricas de latência
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Acessar dashboard de latência

# 2. Identificar serviço problemático
kubectl top pods -n online-boutique

# 3. Verificar logs do serviço lento
kubectl logs -n online-boutique -l app=<service> --tail=100 | grep -i latency
```

### Soluções

#### 1. CPU Throttling

```bash
# Verificar throttling
kubectl top pods -n online-boutique

# Aumentar CPU limits
kubectl set resources deployment/<name> -n online-boutique \
  --limits=cpu=500m --requests=cpu=250m
```

#### 2. Dependências lentas

```bash
# Identificar chamadas entre serviços
kubectl logs -n online-boutique -l app=frontend | grep -E "calling|duration"

# Verificar latência de rede
kubectl exec -it -n online-boutique <pod> -- ping <service-name>
```

#### 3. Falta de cache

**Verificar Redis:**
```bash
kubectl exec -it -n online-boutique <redis-pod> -- redis-cli INFO stats
```

---

## Erros 5xx

### Sintomas
- Taxa de erro > 1%
- Usuários recebendo erros 500/503

### Diagnóstico

```bash
# 1. Identificar serviço com erros
kubectl logs -n online-boutique --all-containers=true | grep -i error

# 2. Verificar eventos
kubectl get events -n online-boutique --sort-by='.lastTimestamp'

# 3. Verificar health checks
kubectl describe pod <pod-name> -n online-boutique | grep -A 5 Liveness
```

### Soluções

#### 1. Serviço downstream indisponível

```bash
# Verificar conectividade entre serviços
kubectl exec -it -n online-boutique <frontend-pod> -- \
  curl http://productcatalogservice:3550

# Verificar DNS
kubectl exec -it -n online-boutique <pod> -- nslookup productcatalogservice
```

#### 2. Timeout em health checks

```yaml
# Aumentar timeout
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30  # Era 10
  timeoutSeconds: 10  # Era 5
  periodSeconds: 15  # Era 10
```

---

## HPA não está escalando

### Sintomas
- CPU > 70% mas réplicas não aumentam
- Tráfego alto mas pods não escalam

### Diagnóstico

```bash
# 1. Verificar status do HPA
kubectl get hpa -n online-boutique

# 2. Verificar métricas disponíveis
kubectl top pods -n online-boutique

# 3. Verificar events do HPA
kubectl describe hpa <hpa-name> -n online-boutique
```

### Soluções

#### 1. Metrics Server não instalado

```bash
# Instalar metrics-server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verificar
kubectl get deployment metrics-server -n kube-system
```

#### 2. Requests não definidos

```yaml
# HPA precisa de resources.requests
spec:
  containers:
  - name: app
    resources:
      requests:
        cpu: 100m  # OBRIGATÓRIO para HPA
        memory: 128Mi
```

#### 3. HPA no máximo de réplicas

```bash
# Verificar se atingiu maxReplicas
kubectl get hpa -n online-boutique

# Aumentar limite
kubectl patch hpa <hpa-name> -n online-boutique -p '{"spec":{"maxReplicas":20}}'
```

---

## OOMKilled

### Sintomas
```
Last State: Terminated
  Reason: OOMKilled
  Exit Code: 137
```

### Diagnóstico

```bash
# 1. Verificar uso de memória
kubectl top pods -n online-boutique

# 2. Verificar histórico de restarts
kubectl get pods -n online-boutique -o wide

# 3. Verificar logs antes do crash
kubectl logs -n online-boutique <pod-name> --previous
```

### Soluções

#### 1. Aumentar memory limits

```bash
kubectl set resources deployment/<name> -n online-boutique \
  --limits=memory=512Mi --requests=memory=256Mi
```

#### 2. Memory leak na aplicação

```bash
# Habilitar profiling (se disponível)
kubectl port-forward -n online-boutique <pod> 6060:6060
# Acessar: http://localhost:6060/debug/pprof/heap
```

---

## CrashLoopBackOff

### Sintomas
```
NAME                          READY   STATUS             RESTARTS   AGE
frontend-7d8f9c8b9d-abc12     0/1     CrashLoopBackOff   5          10m
```

### Diagnóstico

```bash
# 1. Ver logs do container
kubectl logs -n online-boutique <pod-name> --previous

# 2. Verificar eventos
kubectl describe pod <pod-name> -n online-boutique

# 3. Verificar configuração
kubectl get deployment <name> -n online-boutique -o yaml
```

### Soluções Comuns

#### 1. Variável de ambiente faltando

```bash
# Verificar variáveis necessárias
kubectl logs -n online-boutique <pod-name> --previous | grep -i "environment"

# Adicionar no ConfigMap
kubectl edit configmap app-config -n online-boutique
```

#### 2. Dependência não disponível

```bash
# Verificar ordem de inicialização
# Adicionar initContainer se necessário
spec:
  initContainers:
  - name: wait-for-redis
    image: busybox
    command: ['sh', '-c', 'until nc -z redis-cart 6379; do sleep 1; done']
```

---

## 🛠️ Comandos Úteis

### Debug Geral

```bash
# Ver todos os recursos
kubectl get all -n online-boutique

# Ver eventos recentes
kubectl get events -n online-boutique --sort-by='.lastTimestamp' | tail -20

# Executar shell em pod
kubectl exec -it -n online-boutique <pod-name> -- /bin/sh

# Port forward para debug
kubectl port-forward -n online-boutique <pod-name> 8080:8080

# Ver configuração completa
kubectl get deployment <name> -n online-boutique -o yaml

# Verificar recursos do cluster
kubectl describe nodes | grep -A 5 "Allocated resources"
```

### Logs

```bash
# Logs em tempo real
kubectl logs -f -n online-boutique -l app=frontend

# Logs de todos os containers
kubectl logs -n online-boutique <pod-name> --all-containers=true

# Logs anteriores (após crash)
kubectl logs -n online-boutique <pod-name> --previous

# Logs com timestamp
kubectl logs -n online-boutique <pod-name> --timestamps=true
```

### Métricas

```bash
# CPU e Memory dos pods
kubectl top pods -n online-boutique

# CPU e Memory dos nodes
kubectl top nodes

# Métricas detalhadas
kubectl get --raw /apis/metrics.k8s.io/v1beta1/namespaces/online-boutique/pods
```

---

## 📞 Escalação

### Níveis de Suporte

1. **L1 - Operacional**
   - Restart de pods
   - Verificação de logs
   - Monitoramento básico

2. **L2 - Técnico**
   - Análise de métricas
   - Troubleshooting avançado
   - Ajustes de configuração

3. **L3 - Engenharia**
   - Bugs de aplicação
   - Otimização de performance
   - Mudanças arquiteturais

### Quando Escalar

- **Imediato**: SLO breach, service down, data loss
- **1 hora**: Alta latência persistente, erros > 5%
- **4 horas**: Problemas de performance, alertas recorrentes

---

## 📚 Referências

- [Kubernetes Troubleshooting](https://kubernetes.io/docs/tasks/debug/)
- [Prometheus Troubleshooting](https://prometheus.io/docs/prometheus/latest/troubleshooting/)
- [Elasticsearch Troubleshooting](https://www.elastic.co/guide/en/elasticsearch/reference/current/troubleshooting.html)

---

**Última Atualização**: Janeiro 2026  
**Versão**: 1.0.0

