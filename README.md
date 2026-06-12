# central-gitops

Repositorio GitOps para o Continuous Testing Framework. Contem os manifests do Argo CD no padrao App-of-Apps, os values de Helm por microsservico e os ApplicationSets para descoberta automatica de servicos.

## Estrutura

```
central-gitops/
  root-app.yaml           # ct-framework: escaneia apps-core/
  root-app-o11y.yaml      # ct-framework-o11y: escaneia apps-o11y/
  root-app-all.yaml       # ct-framework-all: escaneia tudo (alternativo)
  apps-core/
    namespace-ingress.yaml
    namespace-app.yaml
    argocd-access.yaml
    ingress-nginx.yaml
    catalogo.yaml
    pagamento.yaml
    pedido.yaml
    applicationset.yaml         # Directory generator: tenants/*/apps/*
    applicationset-scm.yaml     # SCM provider: svc-* com label auto-deploy
  apps-o11y/
    namespace.yaml
    alloy.yaml
    grafana.yaml
    loki.yaml
    mimir.yaml
    tempo.yaml
    pyroscope.yaml
  deploy/
    helm/service-chart/   # Helm chart generico (copia de infra-platform)
    helm/values/
      catalogo.yaml
      pagamento.yaml
      pedido.yaml
  argocd-ingress/
    ingress.yaml          # Ingress opcional para o Argo CD UI
```

## Bootstrap

Apos o Terraform provisionar a infraestrutura (AKS + Argo CD), a pipeline do `infra-platform` aplica automaticamente os root-apps:

```bash
kubectl apply -f https://raw.githubusercontent.com/Dorigao-LTDA/central-gitops/main/root-app.yaml
kubectl apply -f https://raw.githubusercontent.com/Dorigao-LTDA/central-gitops/main/root-app-o11y.yaml
```

O `root-app.yaml` (nome `ct-framework`) escaneia `apps-core/` com recurse e cria os namespaces, o ingress-nginx, os 3 microsservicos e os ApplicationSets.

O `root-app-o11y.yaml` (nome `ct-framework-o11y`) escaneia `apps-o11y/` e cria o namespace observability com Alloy, Grafana, Loki, Mimir, Tempo e Pyroscope.

O `root-app-all.yaml` (nome `ct-framework-all`) e uma alternativa que escaneia ambos os diretorios. Nao e usado por padrao.

Ambos os root-apps usam sync automatizado com `prune: true` e `selfHeal: true`.

## Configuracao do ACR

Os arquivos de values em `deploy/helm/values/` referenciam imagens no ACR. Antes do primeiro deploy, substitua o placeholder:

```bash
# Em todos os arquivos de values:
# de: acrctframework.azurecr.io/svc-catalogo
# para: <SEU_ACR_LOGIN_SERVER>/svc-catalogo
```

Os 3 arquivos de values sao: `catalogo.yaml`, `pagamento.yaml`, `pedido.yaml`.

Cada values define: 2 replicas, ingress via NGINX com host `{servico}.dorigao.dev.br`, variaveis OTel, init container do Pyroscope, health probes e limites de recursos.

## Configuracao de DNS

O IP publico do ingress-nginx deve ser configurado nos registros DNS dos dominios:

- `catalogo.dorigao.dev.br`
- `pagamento.dorigao.dev.br`
- `pedido.dorigao.dev.br`
- `argocd.dorigao.dev.br` (se o ingress do Argo CD estiver habilitado)

Obtenha o IP externo do ingress:

```bash
kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

## Componentes de observabilidade

| Componente | Funcao | URL interna |
|---|---|---|
| Alloy | Collector OTLP (metrics, logs, traces) | `alloy.observability.svc.cluster.local:4318` |
| Grafana | Dashboards e visualizacao | `grafana.observability.svc.cluster.local:80` |
| Loki | Armazenamento de logs | `loki.observability.svc.cluster.local:3100` |
| Mimir | Armazenamento de metricas | `mimir.observability.svc.cluster.local:9009` |
| Tempo | Armazenamento de traces | `tempo.observability.svc.cluster.local:3200` |
| Pyroscope | Profiling continuo | `pyroscope.observability.svc.cluster.local:4040` |

## Acesso

**Argo CD** (port-forward):

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
# https://localhost:8080
```

Senha inicial:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

**Grafana** (port-forward):

```bash
kubectl -n observability port-forward svc/grafana 3000:80
# http://localhost:3000
```

## Troubleshooting basico

**Argo CD nao sincroniza os apps.** Verifique se o repositorio esta registrado e se o token de acesso esta valido:

```bash
kubectl -n argocd get secret github-token -o jsonpath='{.data.token}' | base64 -d
```

**ApplicationSet SCM nao descobre repositorios.** Confirme que os repositorios `svc-*` na organizacao `Dorigao-LTDA` possuem a label `auto-deploy`.

**Imagens com erro ImagePullBackOff.** Verifique se o ACR login server nos values esta correto e se o role assignment AcrPull do AKS esta ativo:

```bash
kubectl -n app get pods -o wide
kubectl -n app describe pod <POD_NAME> | grep -A5 Events
```

**Servicos de observabilidade em CrashLoopBackOff.** Verifique os logs e os recursos disponiveis no cluster:

```bash
kubectl -n observability get pods
kubectl -n observability logs <POD_NAME>
kubectl top nodes
```

## Links

- [infra-platform](../infra-platform/README.md): IaC e pipeline de bootstrap
- [Arquitetura](../docs/architecture.md): diagramas e fluxos
- [Guia do desenvolvedor](../docs/developer-guide.md): passo a passo completo
