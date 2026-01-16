# Dockerfile Otimizado - Exemplo para Frontend Service
# Multi-stage build para redução de tamanho e segurança

# Stage 1: Builder
FROM golang:1.21-alpine AS builder

# Instalar dependências de build
RUN apk add --no-cache git ca-certificates tzdata

# Criar usuário não-root
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup

# Definir diretório de trabalho
WORKDIR /build

# Copiar arquivos de dependências primeiro (cache layer)
COPY go.mod go.sum ./
RUN go mod download

# Copiar código fonte
COPY . .

# Build da aplicação com otimizações
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' \
    -a -installsuffix cgo \
    -o /build/server .

# Stage 2: Runtime
FROM scratch

# Copiar certificados CA e timezone data
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Copiar informações de usuário
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group

# Copiar binário compilado
COPY --from=builder /build/server /app/server

# Copiar assets estáticos (se houver)
COPY --from=builder /build/static /app/static
COPY --from=builder /build/templates /app/templates

# Usar usuário não-root
USER appuser:appgroup

# Definir diretório de trabalho
WORKDIR /app

# Variáveis de ambiente
ENV APP_ENV=staging \
    PORT=8080 \
    LOG_LEVEL=info

# Expor porta
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["/app/server", "-healthcheck"]

# Comando de execução
ENTRYPOINT ["/app/server"]

# Labels para metadados
LABEL maintainer="pablo.shizato@gmail.com" \
      version="1.0.0" \
      description="Online Boutique Frontend Service - SRE Pleno Test" \
      org.opencontainers.image.source="https://github.com/GoogleCloudPlatform/microservices-demo"

# Boas práticas implementadas:
# Multi-stage build (redução de ~800MB para ~15MB)
# Usuário não-root (appuser:1001)
# Imagem base minimal (scratch)
# Build estático sem CGO
# Certificados CA incluídos
# Health check configurado
# Variáveis de ambiente parametrizadas
# Labels para rastreabilidade
# Porta configurável via ENV
# Otimizações de compilação (-ldflags)
# Cache de layers otimizado

