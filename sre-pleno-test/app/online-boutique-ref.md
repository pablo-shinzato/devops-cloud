# Online Boutique - Referência

## Repositório Original

**URL**: https://github.com/GoogleCloudPlatform/microservices-demo

## Descrição

Online Boutique é uma aplicação de demonstração de microserviços nativa em cloud desenvolvida pelo Google. Consiste em uma aplicação de e-commerce baseada em 11 microserviços escritos em diferentes linguagens.

## Arquitetura dos Microserviços

```
┌─────────────┐
│   Frontend  │ (Go)
└──────┬──────┘
       │
       ├──────────┐
       │          │
┌──────▼──────┐ ┌▼─────────────┐
│ Cart Service│ │Product Catalog│ (Go)
│    (C#)     │ └───────────────┘
└─────────────┘
       │
┌──────▼──────────┐
│Currency Service │ (Node.js)
└─────────────────┘
       │
┌──────▼──────────┐
│Payment Service  │ (Node.js)
└─────────────────┘
       │
┌──────▼──────────┐
│Shipping Service │ (Go)
└─────────────────┘
       │
┌──────▼──────────┐
│Email Service    │ (Python)
└─────────────────┘
       │
┌──────▼──────────┐
│Checkout Service │ (Go)
└─────────────────┘
       │
┌──────▼──────────────┐
│Recommendation Svc   │ (Python)
└─────────────────────┘
       │
┌──────▼──────────┐
│  Ad Service     │ (Java)
└─────────────────┘
```

## Microserviços

| Serviço | Linguagem | Descrição |
|---------|-----------|-----------|
| frontend | Go | Expõe um servidor HTTP para servir o site. Não requer cadastro/login |
| cartservice | C# | Armazena itens no carrinho do usuário no Redis |
| productcatalogservice | Go | Fornece lista de produtos e capacidade de busca |
| currencyservice | Node.js | Converte valores entre moedas |
| paymentservice | Node.js | Cobra o cartão de crédito com valor fornecido |
| shippingservice | Go | Fornece estimativas de custo de envio |
| emailservice | Python | Envia emails de confirmação aos usuários |
| checkoutservice | Go | Recupera carrinho, prepara pedido e orquestra pagamento/envio/email |
| recommendationservice | Python | Recomenda produtos baseado no carrinho |
| adservice | Java | Fornece anúncios de texto baseados em palavras-chave |
| loadgenerator | Python | Envia requisições imitando fluxo de usuários |

## Tecnologias Utilizadas

- **Kubernetes/GKE**: Orquestração de containers
- **gRPC**: Comunicação entre microserviços
- **Istio**: Service mesh (opcional)
- **OpenTelemetry**: Observabilidade
- **Skaffold**: Desenvolvimento local
- **Redis**: Cache para carrinho de compras

## Como Usar no Projeto

Para este projeto SRE, utilizamos os manifestos Kubernetes da Online Boutique como base, com as seguintes adaptações:

1. **Adição de HPA**: Autoscaling configurado para todos os serviços
2. **ConfigMaps**: Variáveis de ambiente centralizadas
3. **Resources**: Limits e requests definidos
4. **Probes**: Health checks implementados
5. **Observabilidade**: Anotações Prometheus e logs estruturados
6. **Segurança**: SecurityContext e NetworkPolicies

## Comandos Úteis

```bash
# Clonar repositório original (opcional)
git clone https://github.com/GoogleCloudPlatform/microservices-demo.git

# Deploy rápido (sem customizações)
kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/main/release/kubernetes-manifests.yaml

# Verificar status
kubectl get pods

# Acessar frontend
kubectl port-forward svc/frontend-external 8080:80
```

## Referências

- [Documentação Oficial](https://github.com/GoogleCloudPlatform/microservices-demo)
- [Architecture](https://github.com/GoogleCloudPlatform/microservices-demo/blob/main/docs/architecture.md)
- [Development Guide](https://github.com/GoogleCloudPlatform/microservices-demo/blob/main/docs/development-guide.md)

