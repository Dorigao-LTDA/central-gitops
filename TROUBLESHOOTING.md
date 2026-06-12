# Troubleshooting GitOps

Guia de resolucao de problemas comuns no deploy do GitOps com Argo CD.

## Diagnostico rapido

```bash
# 1. Verificar se Argo CD esta instalado
kubectl get pods -n argocd

# 2. Verificar se root applications foram aplicadas
kubectl get applications -n argocd

# 3. Verificar ApplicationSets
kubectl get applicationsets -n argocd

# 4. Verificar logs do Argo CD
kubectl logs -n argocd deployment/argocd-application-controller --tail=50
```

## Causas comuns

### Root applications nao aplicadas

Sintomas: `kubectl get applications -n argocd` retorna "No resources found". Pods do Argo CD existem mas nao ha aplicacoes.

Solucao:

```bash
kubectl apply -f https://raw.githubusercontent.com/Dorigao-LTDA/central-gitops/main/root-app.yaml
kubectl apply -f https://raw.githubusercontent.com/Dorigao-LTDA/central-gitops/main/root-app-o11y.yaml

kubectl get applications -n argocd
```

### ApplicationSets nao aplicados

Sintomas: aplicacoes estaticas (catalogo, pedido, pagamento) aparecem mas ApplicationSets nao. `kubectl get applicationsets -n argocd` retorna vazio.

Os ApplicationSets foram movidos para dentro do diretorio `apps-core/` para serem descobertos pelo root-app. Force a sincronizacao:

```bash
kubectl patch application ct-framework -n argocd -p '{"operation":"sync"}' --type=merge
```

### Aplicacoes em estado "Unknown"

Sintomas: `kubectl get applications -n argocd` mostra STATUS como "Unknown". Apps nao sincronizam automaticamente.

Solucao:

```bash
kubectl patch application ct-framework -n argocd -p '{"operation":"sync"}' --type=merge
kubectl patch application ct-framework-o11y -n argocd -p '{"operation":"sync"}' --type=merge
```

Ou via argocd CLI:

```bash
argocd login localhost:8080
argocd app sync ct-framework
argocd app sync ct-framework-o11y
```

### Erro "path does not exist"

Sintomas: application mostra erro "path apps-core/catalogo does not exist".

O repositorio central-gitops nao tem os arquivos necessarios. Verifique:

```bash
curl -s https://raw.githubusercontent.com/Dorigao-LTDA/central-gitops/main/apps-core/catalogo.yaml | head -5
curl -s https://raw.githubusercontent.com/Dorigao-LTDA/central-gitops/main/deploy/helm/service-chart/Chart.yaml | head -5
```

Se faltarem arquivos, atualize o repositorio central-gitops.

### Helm charts nao encontrados

Sintomas: erros como "chart grafana not found".

O Argo CD baixa charts automaticamente dos repositorios Helm configurados. Verifique conectividade:

```bash
kubectl exec -n argocd deployment/argocd-server -- wget -qO- https://grafana.github.io/helm-charts/index.yaml | head -5
```

### Namespaces nao criados

Sintomas: erro "namespace observability not found".

Solucao:

```bash
kubectl create namespace observability 2>/dev/null || true
kubectl create namespace app 2>/dev/null || true
kubectl create namespace ingress-nginx 2>/dev/null || true
```

## Debugging avancado

```bash
# Estado detalhado de uma application
kubectl describe application ct-framework -n argocd

# Logs do Argo CD application controller em tempo real
kubectl logs -n argocd deployment/argocd-application-controller -f

# Eventos do cluster
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Recriar uma application especifica
kubectl delete application catalogo -n argocd
kubectl apply -f https://raw.githubusercontent.com/Dorigao-LTDA/central-gitops/main/apps-core/catalogo.yaml
```

## Bootstrap manual completo

Se todos os passos anteriores falharem, execute o bootstrap manual:

```bash
# 1. Configurar acesso ao cluster
az aks get-credentials --resource-group <RG> --name <AKS>

# 2. Criar namespaces
kubectl create namespace observability 2>/dev/null || true
kubectl create namespace app 2>/dev/null || true
kubectl create namespace ingress-nginx 2>/dev/null || true

# 3. Aplicar root applications
kubectl apply -f https://raw.githubusercontent.com/Dorigao-LTDA/central-gitops/main/root-app.yaml
kubectl apply -f https://raw.githubusercontent.com/Dorigao-LTDA/central-gitops/main/root-app-o11y.yaml

# 4. Aguardar sincronizacao
sleep 30

# 5. Verificar status
kubectl get applications -n argocd

# 6. Forcar sync se necessario
kubectl patch application ct-framework -n argocd -p '{"operation":"sync"}' --type=merge 2>/dev/null || true
kubectl patch application ct-framework-o11y -n argocd -p '{"operation":"sync"}' --type=merge 2>/dev/null || true
```

## Checklist pos-deploy

- [ ] Pods do Argo CD estao running (`kubectl get pods -n argocd`)
- [ ] Root applications existem (`kubectl get applications -n argocd`)
- [ ] ApplicationSets existem (`kubectl get applicationsets -n argocd`)
- [ ] Namespaces criados: argocd, observability, app, ingress-nginx
- [ ] Ingress nginx foi deployado (`kubectl get pods -n ingress-nginx`)
- [ ] Observabilidade foi deployada (`kubectl get pods -n observability`)
- [ ] Microsservicos aparecem no Argo CD UI

## Links

- [Documentacao Argo CD](https://argo-cd.readthedocs.io/)
- [Repositorio central-gitops](https://github.com/Dorigao-LTDA/central-gitops)
- [Repositorio infra-platform](https://github.com/Dorigao-LTDA/infra-platform)
