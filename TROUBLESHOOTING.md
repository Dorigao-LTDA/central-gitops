# 🚨 Troubleshooting GitOps

Guia de resolução de problemas comuns no deploy do GitOps com ArgoCD.

## Problema: "As aplicações não aparecem no ArgoCD"

### Diagnóstico Rápido

Execute este script no terminal:

```bash
curl -s https://raw.githubusercontent.com/Dorigao-LTDA/central-gitops/main/diagnose-gitops.sh | bash
```

Ou execute os comandos manualmente:

```bash
# 1. Verificar se ArgoCD está instalado
kubectl get pods -n argocd

# 2. Verificar se root applications foram aplicadas
kubectl get applications -n argocd

# 3. Verificar ApplicationSets
kubectl get applicationsets -n argocd

# 4. Verificar logs do ArgoCD
kubectl logs -n argocd deployment/argocd-application-controller --tail=50
```

---

## Causas Comuns e Soluções

### ❌ Causa 1: Root Applications Não Aplicadas

**Sintomas:**
- `kubectl get applications -n argocd` retorna "No resources found"
- Pods do ArgoCD existem mas não há aplicações

**Solução:**
```bash
# Aplicar root applications manualmente
kubectl apply -f https://raw.githubusercontent.com/Dorigao-LTDA/central-gitops/main/root-app.yaml
kubectl apply -f https://raw.githubusercontent.com/Dorigao-LTDA/central-gitops/main/root-app-o11y.yaml

# Verificar
kubectl get applications -n argocd
```

---

### ❌ Causa 2: ApplicationSets Não Aplicados (CORRIGIDO em 02/05/2026)

**Sintomas:**
- Aplicações estáticas (catalogo, pedido, pagamento) aparecem mas ApplicationSets não
- `kubectl get applicationsets -n argocd` retorna vazio

**Solução:**
```bash
# Verificar se ApplicationSets existem no repositório
curl -s https://raw.githubusercontent.com/Dorigao-LTDA/central-gitops/main/apps-core/applicationset.yaml | head -5
curl -s https://raw.githubusercontent.com/Dorigao-LTDA/central-gitops/main/apps-core/applicationset-scm.yaml | head -5

# Se existirem, force a sincronização do root-app
kubectl patch application ct-framework -n argocd -p '{"operation":"sync"}' --type=merge
```

**Nota:** Este problema foi corrigido movendo os ApplicationSets para dentro do diretório `apps-core/`.

---

### ❌ Causa 3: Aplicações em Estado "Unknown"

**Sintomas:**
- `kubectl get applications -n argocd` mostra STATUS como "Unknown"
- Apps não sincronizam automaticamente

**Solução:**
```bash
# Forçar sincronização
kubectl patch application ct-framework -n argocd -p '{"operation":"sync"}' --type=merge
kubectl patch application ct-framework-o11y -n argocd -p '{"operation":"sync"}' --type=merge

# Ou usando argocd CLI
argocd login localhost:8080
argocd app sync ct-framework
argocd app sync ct-framework-o11y
```

---

### ❌ Causa 4: Erro "path does not exist"

**Sintomas:**
- Application mostra erro: "path apps-core/catalogo does not exist"
- Diretórios não encontrados no repo

**Causa:** O repositório central-gitops não tem os arquivos necessários

**Solução:**
Verifique se todos os diretórios existem:
```bash
# Deve retornar conteúdo
curl -s https://raw.githubusercontent.com/Dorigao-LTDA/central-gitops/main/apps-core/catalogo.yaml | head -5
curl -s https://raw.githubusercontent.com/Dorigao-LTDA/central-gitops/main/deploy/helm/service-chart/Chart.yaml | head -5
```

Se faltarem arquivos, atualize o repositório central-gitops.

---

### ❌ Causa 5: Helm Charts Não Encontrados

**Sintomas:**
- Erros como "chart "grafana" not found"
- Repositórios Helm não configurados

**Verificação:**
```bash
# Verificar se ArgoCD consegue acessar os repositórios Helm
kubectl exec -n argocd deployment/argocd-server -- helm repo list
```

**Solução:**
O ArgoCD baixa charts automaticamente, mas pode haver problema de conectividade. Verifique:
```bash
# Testar conectividade
kubectl exec -n argocd deployment/argocd-server -- wget -qO- https://grafana.github.io/helm-charts/index.yaml | head -5
```

---

### ❌ Causa 6: Namespaces Não Criados

**Sintomas:**
- Erro: "namespace observability not found"
- Pods não são criados

**Solução:**
```bash
# Criar namespaces manualmente
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace app --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -

# Ou force recriação
kubectl create namespace observability 2>/dev/null || true
```

---

## 🔍 Debugging Avançado

### Verificar Estado Detalhado de uma Application

```bash
kubectl describe application ct-framework -n argocd
```

### Ver Logs do ArgoCD Application Controller

```bash
# Logs em tempo real
kubectl logs -n argocd deployment/argocd-application-controller -f

# Últimas 100 linhas
kubectl logs -n argocd deployment/argocd-application-controller --tail=100
```

### Ver Eventos do Cluster

```bash
# Todos os eventos
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Eventos do ArgoCD
kubectl get events -n argocd --sort-by='.lastTimestamp'
```

### Recriar uma Application Específica

```bash
# Deletar e recriar
kubectl delete application catalogo -n argocd
kubectl apply -f https://raw.githubusercontent.com/Dorigao-LTDA/central-gitops/main/apps-core/catalogo.yaml
```

---

## 🔄 Fluxo de Bootstrap Correto

Se tudo falhar, execute o bootstrap manual completo:

```bash
#!/bin/bash
set -e

echo "🚀 GitOps Manual Bootstrap"
echo ""

# 1. Configurar acesso
az aks get-credentials --resource-group <RG> --name <AKS>

# 2. Criar namespaces
echo "Criando namespaces..."
kubectl create namespace observability 2>/dev/null || true
kubectl create namespace app 2>/dev/null || true
kubectl create namespace ingress-nginx 2>/dev/null || true

# 3. Aplicar root applications
echo "Aplicando root applications..."
kubectl apply -f https://raw.githubusercontent.com/Dorigao-LTDA/central-gitops/main/root-app.yaml
kubectl apply -f https://raw.githubusercontent.com/Dorigao-LTDA/central-gitops/main/root-app-o11y.yaml

# 4. Aguardar
echo "Aguardando 30 segundos..."
sleep 30

# 5. Verificar
echo "Status das aplicações:"
kubectl get applications -n argocd

# 6. Forçar sync se necessário
echo "Forçando sincronização..."
kubectl patch application ct-framework -n argocd -p '{"operation":"sync"}' --type=merge 2>/dev/null || true
kubectl patch application ct-framework-o11y -n argocd -p '{"operation":"sync"}' --type=merge 2>/dev/null || true

echo ""
echo "✅ Bootstrap completo!"
echo "Verifique em: kubectl get applications -n argocd -w"
```

---

## 📝 Checklist de Verificação

Após o deploy, verifique:

- [ ] Pods do ArgoCD estão running (`kubectl get pods -n argocd`)
- [ ] Root applications existem (`kubectl get applications -n argocd`)
- [ ] ApplicationSets existem (`kubectl get applicationsets -n argocd`)
- [ ] Namespaces criados: argocd, observability, app, ingress-nginx
- [ ] Ingress nginx foi deployado (`kubectl get pods -n ingress-nginx`)
- [ ] Observabilidade foi deployada (`kubectl get pods -n observability`)
- [ ] Microserviços aparecem no ArgoCD UI

---

## 🆘 Ainda com Problemas?

1. Verifique se você está na branch correta do central-gitops
2. Confirme que o repositório está público ou que ArgoCD tem acesso
3. Verifique se há algum webhook ou branch protection bloqueando
4. Consulte os logs completos do ArgoCD

**Links Úteis:**
- [Documentação ArgoCD](https://argo-cd.readthedocs.io/)
- [Repositório central-gitops](https://github.com/Dorigao-LTDA/central-gitops)
- [Repositório infra-platform](https://github.com/Dorigao-LTDA/infra-platform)
