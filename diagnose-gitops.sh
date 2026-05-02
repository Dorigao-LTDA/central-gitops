#!/bin/bash
# Script de Diagnóstico Completo do GitOps/ArgoCD
# Execute este script para identificar problemas no deploy

set -e

echo "=========================================="
echo "🔍 DIAGNÓSTICO COMPLETO DO GITOPS"
echo "=========================================="
echo ""

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}$1${NC}"
    echo "----------------------------------------"
}

print_ok() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Array para armazenar problemas
declare -a PROBLEMAS=()
declare -a SOLUCOES=()

adicionar_problema() {
    PROBLEMAS+=("$1")
    SOLUCOES+=("$2")
}

print_header "1️⃣  Verificando Conectividade com o Cluster"
if kubectl cluster-info &>/dev/null; then
    print_ok "Conectado ao cluster Kubernetes"
    kubectl cluster-info | head -3
else
    print_error "Não foi possível conectar ao cluster"
    adicionar_problema "kubectl não conectado ao cluster" "Execute: az aks get-credentials --resource-group <RG> --name <AKS>"
fi
echo ""

print_header "2️⃣  Verificando Namespaces"
NS_LIST="argocd observability app ingress-nginx"
for ns in $NS_LIST; do
    if kubectl get namespace "$ns" &>/dev/null; then
        print_ok "Namespace '$ns' existe"
    else
        print_error "Namespace '$ns' NÃO existe"
        adicionar_problema "Namespace $ns não existe" "kubectl create namespace $ns"
    fi
done
echo ""

print_header "3️⃣  Verificando CRDs do ArgoCD"
ARGOCD_CRDS=$(kubectl get crd --no-headers 2>/dev/null | grep argoproj.io | wc -l)
if [ "$ARGOCD_CRDS" -gt 0 ]; then
    print_ok "CRDs do ArgoCD instalados ($ARGOCD_CRDS CRDs)"
    kubectl get crd | grep argoproj.io | awk '{print "  - " $1}'
else
    print_error "CRDs do ArgoCD NÃO encontrados"
    adicionar_problema "ArgoCD CRDs não instalados" "O Terraform deve ter instalado. Verifique o estado do helm release."
fi
echo ""

print_header "4️⃣  Verificando Pods do ArgoCD"
ARGOCD_PODS=$(kubectl get pods -n argocd --no-headers 2>/dev/null | wc -l)
if [ "$ARGOCD_PODS" -gt 0 ]; then
    print_ok "ArgoCD está instalado ($ARGOCD_PODS pods)"
    kubectl get pods -n argocd
    
    # Verificar se todos os pods estão running
    NOT_RUNNING=$(kubectl get pods -n argocd --no-headers | grep -v Running | wc -l)
    if [ "$NOT_RUNNING" -gt 0 ]; then
        print_warning "Alguns pods não estão em estado Running:"
        kubectl get pods -n argocd | grep -v Running
        adicionar_problema "Pods do ArgoCD não estão prontos" "Aguarde ou verifique: kubectl describe pod <pod-name> -n argocd"
    fi
else
    print_error "Nenhum pod do ArgoCD encontrado"
    adicionar_problema "ArgoCD não instalado" "Verifique se o Terraform aplicou o módulo argocd"
fi
echo ""

print_header "5️⃣  Verificando Serviços do ArgoCD"
kubectl get svc -n argocd 2>/dev/null || print_error "Não foi possível obter serviços"
echo ""

print_header "6️⃣  Verificando Applications"
APPS=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l)
if [ "$APPS" -gt 0 ]; then
    print_ok "Encontradas $APPS Applications"
    echo ""
    echo "Status das Applications:"
    kubectl get applications -n argocd
    echo ""
    
    # Verificar aplicações com erro
    UNHEALTHY=$(kubectl get applications -n argocd --no-headers | grep -v Healthy | wc -l)
    if [ "$UNHEALTHY" -gt 0 ]; then
        print_warning "Aplicações não saudáveis encontradas:"
        kubectl get applications -n argocd | grep -v Healthy
        echo ""
        print_warning "Para mais detalhes, execute:"
        echo "  kubectl describe application <nome> -n argocd"
        adicionar_problema "Aplicações em estado não saudável" "Verifique logs: kubectl logs deployment/argocd-application-controller -n argocd"
    fi
else
    print_error "NENHUMA Application encontrada!"
    print_warning "As root applications provavelmente não foram aplicadas"
    adicionar_problema "Root applications não aplicadas" "Execute:\nkubectl apply -f https://raw.githubusercontent.com/Dorigao-LTDA/central-gitops/main/root-app.yaml\nkubectl apply -f https://raw.githubusercontent.com/Dorigao-LTDA/central-gitops/main/root-app-o11y.yaml"
fi
echo ""

print_header "7️⃣  Verificando ApplicationSets"
APPSETS=$(kubectl get applicationsets -n argocd --no-headers 2>/dev/null | wc -l)
if [ "$APPSETS" -gt 0 ]; then
    print_ok "Encontrados $APPSETS ApplicationSets"
    kubectl get applicationsets -n argocd
else
    print_error "NENHUM ApplicationSet encontrado!"
    print_warning "ApplicationSets não estão sendo aplicados pelo root-app"
    adicionar_problema "ApplicationSets não aplicados" "Verifique se estão no diretório apps-core/ no repositório central-gitops"
fi
echo ""

print_header "8️⃣  Verificando Pods de Aplicações (Core)"
echo "Ingress Nginx:"
kubectl get pods -n ingress-nginx --no-headers 2>/dev/null | head -3 || print_warning "Nenhum pod encontrado em ingress-nginx"
echo ""

echo "Observabilidade:"
kubectl get pods -n observability --no-headers 2>/dev/null | head -5 || print_warning "Nenhum pod encontrado em observability"
echo ""

echo "Aplicações:"
kubectl get pods -n app --no-headers 2>/dev/null | head -5 || print_warning "Nenhum pod encontrado em app"
echo ""

print_header "9️⃣  Verificando Logs do ArgoCD (últimas 30 linhas)"
echo "Application Controller:"
kubectl logs -n argocd deployment/argocd-application-controller --tail=30 2>/dev/null || print_error "Não foi possível obter logs"
echo ""

print_header "🔟  Verificando Eventos Recentes"
kubectl get events --all-namespaces --sort-by='.lastTimestamp' 2>/dev/null | tail -15 || print_warning "Não foi possível obter eventos"
echo ""

# RESUMO
echo ""
echo "=========================================="
echo "📋 RESUMO DOS PROBLEMAS ENCONTRADOS"
echo "=========================================="

if [ ${#PROBLEMAS[@]} -eq 0 ]; then
    print_ok "Nenhum problema crítico encontrado!"
    echo ""
    echo "Se as aplicações ainda não aparecem no ArgoCD UI:"
    echo "  1. Acesse o ArgoCD: kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "  2. Abra https://localhost:8080"
    echo "  3. Login: admin / $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d 2>/dev/null || echo '<senha>')"
    echo ""
    echo "Se necessário, force a sincronização:"
    echo "  kubectl patch application ct-framework -n argocd -p '{\"operation\":\"sync\"}' --type=merge"
    echo "  kubectl patch application ct-framework-o11y -n argocd -p '{\"operation\":\"sync\"}' --type=merge"
else
    print_error "${#PROBLEMAS[@]} problema(s) encontrado(s):"
    echo ""
    for i in "${!PROBLEMAS[@]}"; do
        echo -e "${RED}Problema $((i+1)):${NC} ${PROBLEMAS[$i]}"
        echo -e "${GREEN}Solução:${NC}"
        echo -e "${SOLUCOES[$i]}" | sed 's/^/  /'
        echo ""
    done
fi

echo "=========================================="
echo "🔧 COMANDOS RÁPIDOS DE CORREÇÃO"
echo "=========================================="
echo ""
echo "Se você acabou de fazer o deploy e as apps não aparecem:"
echo ""
echo "# 1. Verifique se ArgoCD está rodando"
echo "kubectl get pods -n argocd"
echo ""
echo "# 2. Aplique os root applications"
echo "kubectl apply -f https://raw.githubusercontent.com/Dorigao-LTDA/central-gitops/main/root-app.yaml"
echo "kubectl apply -f https://raw.githubusercontent.com/Dorigao-LTDA/central-gitops/main/root-app-o11y.yaml"
echo ""
echo "# 3. Aguarde e verifique"
echo "sleep 30 && kubectl get applications -n argocd"
echo ""
echo "# 4. Se estiverem em estado 'Unknown', force a sincronização"
echo "argocd app sync ct-framework || kubectl patch application ct-framework -n argocd -p '{\"operation\":\"sync\"}' --type=merge"
echo "argocd app sync ct-framework-o11y || kubectl patch application ct-framework-o11y -n argocd -p '{\"operation\":\"sync\"}' --type=merge"
echo ""
echo "# 5. Verifique o status de todas as apps"
echo "kubectl get applications -n argocd"
echo ""
echo "=========================================="
