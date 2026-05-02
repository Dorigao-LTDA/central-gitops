# Argo CD - GitOps Bootstrap

Bootstrap GitOps para o projeto ct-framework usando o padrão App-of-Apps.

## 📋 Estrutura

```
.
├── root-app.yaml              # Root application - core
├── root-app-o11y.yaml         # Root application - observability
├── apps-core/                 # Aplicações core
│   ├── namespace-ingress.yaml # Namespace ingress-nginx
│   ├── namespace-app.yaml     # Namespace app
│   ├── argocd-access.yaml     # Ingress do ArgoCD
│   ├── ingress-nginx.yaml     # NGINX Ingress Controller
│   ├── catalogo.yaml          # Microserviço
│   ├── pedido.yaml            # Microserviço
│   ├── pagamento.yaml         # Microserviço
│   ├── applicationset.yaml    # Discovery de apps por diretório
│   └── applicationset-scm.yaml # Discovery por SCM
├── apps-o11y/                 # Stack de observabilidade
│   ├── namespace.yaml         # Namespace observability
│   ├── alloy.yaml            # OTLP Collector
│   ├── grafana.yaml          # Dashboards
│   ├── loki.yaml             # Logs
│   ├── mimir.yaml            # Métricas
│   ├── tempo.yaml            # Traces
│   └── pyroscope.yaml        # Profiling
├── argocd-ingress/            # Manifestos de ingress
│   └── ingress.yaml
└── deploy/helm/               # Helm charts
    ├── service-chart/        # Chart genérico para microserviços
    └── values/               # Values específicos por serviço
        ├── catalogo.yaml
        ├── pedido.yaml
        └── pagamento.yaml
```

## 🚀 Bootstrap

Após o deploy da infraestrutura via Terraform, execute o bootstrap manual:

```bash
# 1. Configurar acesso ao cluster
az aks get-credentials --resource-group <AKS_RESOURCE_GROUP> --name <AKS_CLUSTER_NAME>

# 2. Aplicar root applications
kubectl apply -f root-app.yaml
kubectl apply -f root-app-o11y.yaml

# 3. Verificar aplicações
kubectl get applications -n argocd

# 4. Aguardar sincronização
kubectl get applications -n argocd -w
```

## ⚙️ Configurações Importantes

### 🔧 Configurando seu ACR

Os microserviços (catalogo, pedido, pagamento) usam uma imagem nginx por padrão para demonstração.

Para usar seu próprio ACR, edite os arquivos em `deploy/helm/values/`:

```yaml
image:
  # Substitua pelo seu ACR
  # Exemplo: acrctframework.azurecr.io/catalogo
  repository: <SEU_ACR>.azurecr.io/catalogo
  tag: "latest"
```

**Aplicar mudanças:**
```bash
# Após editar e commitar, force sync
kubectl patch application catalogo -n argocd -p '{"operation":"sync"}' --type=merge
```

### 🔧 Configurando DNS e Ingress

O Ingress Controller usa **IP dinâmico** do Azure por padrão. Para configurar seu domínio:

```bash
# 1. Obter o IP atribuído pelo Azure
kubectl get svc -n ingress-nginx
# Anote o valor em EXTERNAL-IP

# 2. Configure seu DNS para apontar para este IP
# catalogo.dorigao.dev.br -> <IP_DO_INGRESS>
# pedido.dorigao.dev.br -> <IP_DO_INGRESS>
# pagamento.dorigao.dev.br -> <IP_DO_INGRESS>
```

**Para usar IP estático:**

Edite `apps-core/ingress-nginx.yaml` e adicione:

```yaml
controller:
  service:
    type: LoadBalancer
    loadBalancerIP: "SEU.IP.AQUI.ESTATICO"
```

### 🔧 Configurando ArgoCD UI

Por padrão, o ArgoCD é acessível apenas via port-forward:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Acesse: https://localhost:8080

**Credenciais:**
- Username: `admin`
- Password: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`

Para expor via DNS, edite `argocd-ingress/ingress.yaml` com seu domínio e certificado.

## 📊 Componentes

### Observability Stack

| Componente | Propósito | URL Interna |
|------------|-----------|-------------|
| **Alloy** | Coletor OTLP | `alloy.observability.svc.cluster.local:4318` |
| **Grafana** | Dashboards | `grafana.observability.svc.cluster.local:3000` |
| **Loki** | Logs | `loki-gateway.observability.svc.cluster.local:4318` |
| **Mimir** | Métricas | `mimir-distributed-nginx.observability.svc.cluster.local:4318` |
| **Tempo** | Traces | `tempo.observability.svc.cluster.local:4318` |
| **Pyroscope** | Profiling | `pyroscope.observability.svc.cluster.local:4040` |

### Acesso ao Grafana

```bash
# Port-forward
kubectl port-forward svc/grafana -n observability 3000:80

# Acesse http://localhost:3000
# Login: admin / changeme (altere no arquivo grafana.yaml)
```

## 🔍 Troubleshooting

### Aplicações em estado "Unknown"

```bash
# Verificar detalhes
kubectl describe application <nome> -n argocd

# Forçar sincronização
kubectl patch application <nome> -n argocd -p '{"operation":"sync"}' --type=merge
```

### Pods com ImagePullBackOff

Verifique se o AKS tem acesso ao ACR:

```bash
# Conectar ACR ao AKS
az aks update --name <AKS_NAME> --resource-group <AKS_RG> --attach-acr <ACR_NAME>
```

### Logs do ArgoCD

```bash
kubectl logs -n argocd deployment/argocd-application-controller --tail=100
```

## 📝 Notas

- Namespaces são criados automaticamente pelos manifests em `apps-core/` e `apps-o11y/`
- Todas as aplicações têm syncPolicy automático habilitado
- O alloy (observability) tem `selfHeal: false` para evitar conflitos de configuração
- Os microserviços são configurados via Helm chart genérico em `deploy/helm/service-chart/`
- OTLP (OpenTelemetry) está configurado por padrão em todos os serviços

## 🔗 Links

- [Repositório Infra Platform](https://github.com/Dorigao-LTDA/infra-platform)
- [Documentação ArgoCD](https://argo-cd.readthedocs.io/)
- [Helm Charts NGINX Ingress](https://kubernetes.github.io/ingress-nginx/)
