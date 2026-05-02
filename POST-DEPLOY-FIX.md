# 🚨 Resolução de Problemas Comuns Pós-Deploy

Este guia resolve os problemas mais comuns após o deploy inicial do GitOps.

## Problemas Atuais

```
NAME                SYNC STATUS   HEALTH STATUS
alloy               OutOfSync     Missing
argocd-access       Synced        Progressing
catalogo            Unknown       Healthy
ct-framework        Synced        Degraded
ct-framework-o11y   Synced        Healthy
grafana             OutOfSync     Missing
ingress-nginx       OutOfSync     Missing
loki                OutOfSync     Missing
mimir               OutOfSync     Missing
pagamento           Unknown       Healthy
pedido              Unknown       Healthy
pyroscope           OutOfSync     Missing
tempo               OutOfSync     Missing
```

---

## 🔴 Problema 1: Observability Stack (alloy, grafana, loki, mimir, pyroscope, tempo)

**Status:** OutOfSync + Missing

### Causa
O namespace `observability` não existe ou os charts Helm não estão sendo baixados.

### Solução Rápida

```bash
# 1. Criar namespace
kubectl create namespace observability

# 2. Forçar sincronização
echo "alloy grafana loki mimir pyroscope tempo" | tr ' ' '\n' | while read app; do
  kubectl patch application "$app" -n argocd -p '{"operation":"sync"}' --type=merge
done

# 3. Aguardar
sleep 30

# 4. Verificar
kubectl get pods -n observability
```

### Se ainda falhar

Verifique se o ArgoCD consegue acessar os repositórios Helm:

```bash
# Testar acesso aos charts
kubectl exec -n argocd deployment/argocd-server -- \
  wget -qO- https://grafana.github.io/helm-charts/index.yaml | head -5

# Se falhar, pode ser problema de conectividade
# Verificar logs
kubectl logs -n argocd deployment/argocd-application-controller | grep -i "grafana"
```

---

## 🔴 Problema 2: Ingress Nginx

**Status:** OutOfSync + Missing

### Causa
Namespace `ingress-nginx` não existe.

### Solução Rápida

```bash
# 1. Criar namespace
kubectl create namespace ingress-nginx

# 2. Forçar sincronização
kubectl patch application ingress-nginx -n argocd -p '{"operation":"sync"}' --type=merge

# 3. Verificar
kubectl get pods -n ingress-nginx -w
```

### ⚠️ Importante: IP Público

O `ingress-nginx.yaml` contém um placeholder que precisa ser substituído:

```yaml
# Editar: central-gitops/apps-core/ingress-nginx.yaml
controller:
  service:
    type: LoadBalancer
    loadBalancerIP: "REPLACE_WITH_INGRESS_PUBLIC_IP"  # <-- SUBSTITUIR
```

**Opções:**

**Opção A - IP Dinâmico (mais fácil):**
Remova a linha `loadBalancerIP` e deixe o Azure atribuir um IP automaticamente.

**Opção B - IP Estático:**
1. Crie um IP público no Azure Portal
2. Substitua o placeholder

```bash
# Obter IP atribuído (após deploy)
kubectl get svc -n ingress-nginx
# Anote o IP em EXTERNAL-IP
```

---

## 🟡 Problema 3: Microserviços (catalogo, pagamento, pedido)

**Status:** Unknown + Healthy

### Causa
Status "Unknown" geralmente significa que o ArgoCD está aguardando os recursos serem criados. Os pods podem estar com erro de "ImagePullBackOff" porque o ACR não está configurado.

### Solução

**Passo 1: Verificar pods**
```bash
kubectl get pods -n app
kubectl describe pod <nome-do-pod> -n app
```

**Passo 2: Configurar ACR**

Os arquivos de values têm `REPLACE_WITH_ACR`:

```bash
# Obter login server do ACR
az acr show --name <ACR_NAME> --query loginServer -o tsv
# Exemplo: acrctframework.azurecr.io
```

Edite os arquivos no central-gitops:
- `deploy/helm/values/catalogo.yaml`
- `deploy/helm/values/pagamento.yaml`
- `deploy/helm/values/pedido.yaml`

Substitua `REPLACE_WITH_ACR` pelo seu ACR login server.

**Passo 3: Garantir que AKS pode acessar o ACR**

```bash
# Attach ACR ao AKS
az aks update --name <AKS_NAME> --resource-group <AKS_RG> --attach-acr <ACR_NAME>

# Ou manualmente
ACR_ID=$(az acr show --name <ACR_NAME> --query id -o tsv)
AKS_SP=$(az aks show --name <AKS_NAME> --resource-group <AKS_RG> --query servicePrincipalProfile.clientId -o tsv)
az role assignment create --assignee $AKS_SP --role AcrPull --scope $ACR_ID
```

**Passo 4: Forçar sincronização**
```bash
for app in catalogo pagamento pedido; do
  kubectl patch application "$app" -n argocd -p '{"operation":"sync"}' --type=merge
done
```

---

## 🟡 Problema 4: ArgoCD Access

**Status:** Synced + Progressing

### Causa
O ingress está tentando ser criado mas o ingress controller (nginx) ainda não está pronto.

### Solução

1. Primeiro resolva o problema do ingress-nginx
2. Depois sincronize:

```bash
kubectl patch application argocd-access -n argocd -p '{"operation":"sync"}' --type=merge
```

---

## 🟠 Problema 5: ct-framework Degraded

**Status:** Synced + Degraded

### Causa
Uma ou mais aplicações filhas estão com problemas (provavelmente as que mencionamos acima).

### Solução
Resolva os problemas das aplicações filhas e este root app ficará saudável automaticamente.

---

## ✅ Script de Correção Automática

Execute este script que automatiza todas as correções:

```bash
# Baixar e executar
curl -s https://raw.githubusercontent.com/Dorigao-LTDA/central-gitops/main/fix-gitops-issues.sh | bash

# Ou baixar primeiro
wget https://raw.githubusercontent.com/Dorigao-LTDA/central-gitops/main/fix-gitops-issues.sh
chmod +x fix-gitops-issues.sh
./fix-gitops-issues.sh
```

O script irá:
1. ✅ Criar namespaces faltantes
2. ✅ Forçar sincronização das apps problemáticas
3. ✅ Mostrar status atualizado
4. ✅ Verificar pods em cada namespace
5. ✅ Identificar eventos de erro

---

## 🔍 Comandos de Verificação

### Ver todas as apps e seu status
```bash
kubectl get applications -n argocd
```

### Ver detalhes de uma app específica
```bash
kubectl describe application <nome> -n argocd
```

### Ver logs do ArgoCD
```bash
kubectl logs -n argocd deployment/argocd-application-controller --tail=100
```

### Ver pods em todos os namespaces
```bash
kubectl get pods --all-namespaces
```

### Ver eventos de erro
```bash
kubectl get events --all-namespaces --field-selector type=Warning
```

---

## 🎯 Checklist de Correção

- [ ] Criar namespace `observability`
- [ ] Criar namespace `ingress-nginx`
- [ ] Sincronizar observability stack
- [ ] Sincronizar ingress-nginx
- [ ] Configurar IP no ingress-nginx.yaml (ou remover para IP dinâmico)
- [ ] Configurar ACR nos values dos microserviços
- [ ] Garantir que AKS tem acesso ao ACR (AcrPull)
- [ ] Sincronizar microserviços
- [ ] Verificar se todas as apps ficaram Healthy

---

## 🆘 Ainda com Problemas?

1. **Verifique os logs detalhados:**
```bash
# Logs do application controller
kubectl logs -n argocd deployment/argocd-application-controller -f

# Logs do repo server
kubectl logs -n argocd deployment/argocd-repo-server -f
```

2. **Verifique se há erros de permissão:**
```bash
# O ArgoCD precisa de permissão para criar recursos
kubectl auth can-i create deployment --all-namespaces
```

3. **Reinicie o ArgoCD (último recurso):**
```bash
kubectl rollout restart deployment/argocd-application-controller -n argocd
kubectl rollout restart deployment/argocd-repo-server -n argocd
```

4. **Verifique documentação completa:**
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- [README.md](README.md)
