# Argo CD - GitOps Bootstrap

Bootstrap GitOps para o projeto ct-framework usando o padrão App-of-Apps.

## 📋 Pré-requisitos

- AKS cluster deployado via Terraform (`infra-platform`)
- ACR (Azure Container Registry) criado
- IP Público do Azure para Ingress (opcional, mas recomendado)

## 🚀 Bootstrap do GitOps

Após o deploy da infraestrutura via Terraform, execute o bootstrap manual:

### 1. Configurar acesso ao cluster

```bash
# Obter credenciais do AKS
az aks get-credentials --resource-group <AKS_RESOURCE_GROUP> --name <AKS_CLUSTER_NAME>

# Verificar conexão
kubectl get nodes
```

### 2. Aplicar Root Applications

```bash
# Aplicar app principal (core apps)
kubectl apply -f root-app.yaml

# Aplicar observability stack
kubectl apply -f root-app-o11y.yaml

# Verificar aplicações
kubectl get applications -n argocd
```

### 3. Configurar Ingress (IMPORTANTE!)

O arquivo `apps-core/ingress-nginx.yaml` contém um placeholder que precisa ser substituído:

```bash
# Obter o IP público do Ingress (se criado manualmente no Azure)
# ou deixe o Azure criar um automaticamente removendo a linha loadBalancerIP

# Editar apps-core/ingress-nginx.yaml
# Substitua: REPLACE_WITH_INGRESS_PUBLIC_IP
# Pelo seu IP público ou remova a linha para IP dinâmico
```

### 4. Configurar ACR

Substitua `REPLACE_WITH_ACR` nos arquivos de values:
- `deploy/helm/values/catalogo.yaml`
- `deploy/helm/values/pedido.yaml`
- `deploy/helm/values/pagamento.yaml`

```bash
# Obter o login server do ACR
az acr show --name <ACR_NAME> --query loginServer -o tsv

# Exemplo: acrctframework.azurecr.io
```

## 📁 Estrutura do Repositório

```
.
├── root-app.yaml              # Root application - core
├── root-app-o11y.yaml         # Root application - observability
├── apps-core/                 # Aplicações core
│   ├── argocd-access.yaml     # Ingress do ArgoCD
│   ├── ingress-nginx.yaml     # NGINX Ingress Controller
│   ├── catalogo.yaml          # Microserviço
│   ├── pedido.yaml            # Microserviço
│   └── pagamento.yaml         # Microserviço
├── apps-o11y/                 # Stack de observabilidade
│   ├── alloy.yaml            # OTLP Collector
│   ├── grafana.yaml          # Dashboards
│   ├── loki.yaml             # Logs
│   ├── mimir.yaml            # Métricas
│   ├── tempo.yaml            # Traces
│   └── pyroscope.yaml        # Profiling
├── argocd-ingress/            # Manifestos de ingress
│   └── ingress.yaml
├── deploy/helm/               # Helm charts
│   ├── service-chart/        # Chart genérico para microserviços
│   └── values/               # Values específicos por serviço
└── README.md
```

## 🔧 Troubleshooting

### Aplicações em estado "Unknown" ou "Missing"

Verifique os logs do ArgoCD:
```bash
kubectl logs -n argocd deployment/argocd-application-controller
```

### Erro: "path does not exist"

Se o ArgoCD reportar que um path não existe:
1. Verifique se o diretório existe neste repo
2. Confirme que o repo está sincronizado
3. Verifique as permissões de acesso do ArgoCD ao repo

### Observabilidade não aparece

Verifique se o namespace existe:
```bash
kubectl create namespace observability
kubectl apply -f root-app-o11y.yaml
```

### Microserviços não iniciam

1. Verifique se as imagens existem no ACR
2. Confirme se o AKS tem acesso ao ACR (AcrPull role)
3. Verifique os values no diretório `deploy/helm/values/`

### ArgoCD não acessível

Por padrão, o ArgoCD usa ClusterIP. Para acessar:
```bash
# Port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Acesse: https://localhost:8080
# Senha inicial:
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Para expor via Ingress (requer IP público):
1. Configure o `argocd-access.yaml`
2. Atualize o DNS para apontar para o IP do Ingress

## 📝 Notas

- Todas as aplicações têm syncPolicy automático habilitado
- O alloy (observability) tem `selfHeal: false` para evitar conflitos de configuração
- Os microserviços são configurados via Helm chart genérico em `deploy/helm/service-chart/`
- OTLS (OpenTelemetry) está configurado por padrão em todos os serviços

## 🔗 Links Úteis

- [Repositório Infra Platform](https://github.com/Dorigao-LTDA/infra-platform)
- [Documentação ArgoCD](https://argo-cd.readthedocs.io/)
- [Helm Charts NGINX Ingress](https://kubernetes.github.io/ingress-nginx/)
