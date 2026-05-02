#!/bin/bash
# Script de Correção dos Problemas do GitOps
# Corrige namespaces faltantes e força sincronização

set -e

echo "=========================================="
echo "🔧 CORREÇÃO DOS PROBLEMAS DO GITOPS"
echo "=========================================="
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}$1${NC}"
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

# 1. Criar namespaces faltantes
print_header "1️⃣  Criando Namespaces Faltantes"
echo "----------------------------------------"

for ns in observability app ingress-nginx; do
    if kubectl get namespace "$ns" &>/dev/null; then
        print_ok "Namespace '$ns' já existe"
    else
        echo "Criando namespace '$ns'..."
        kubectl create namespace "$ns"
        print_ok "Namespace '$ns' criado"
    fi
done
echo ""

# 2. Forçar sincronização das aplicações problemáticas
print_header "2️⃣  Forçando Sincronização das Aplicações"
echo "----------------------------------------"

# Lista de apps com problemas
UNHEALTHY_APPS="alloy grafana loki mimir pyroscope tempo ingress-nginx"

for app in $UNHEALTHY_APPS; do
    echo "Sincronizando $app..."
    kubectl patch application "$app" -n argocd -p '{"operation":"sync"}' --type=merge 2>/dev/null || {
        print_warning "Não foi possível sincronizar $app (pode não existir ainda)"
    }
done

# Aguardar um pouco
print_warning "Aguardando 20 segundos para aplicações iniciarem..."
sleep 20
echo ""

# 3. Verificar status após correções
print_header "3️⃣  Status Após Correções"
echo "----------------------------------------"
kubectl get applications -n argocd
echo ""

# 4. Verificar pods nos namespaces
print_header "4️⃣  Verificando Pods nos Namespaces"
echo "----------------------------------------"

echo "📦 Namespace: observability"
kubectl get pods -n observability 2>/dev/null || print_error "Nenhum pod encontrado"
echo ""

echo "📦 Namespace: ingress-nginx"
kubectl get pods -n ingress-nginx 2>/dev/null || print_error "Nenhum pod encontrado"
echo ""

echo "📦 Namespace: app"
kubectl get pods -n app 2>/dev/null || print_warning "Nenhum pod encontrado (normal se ACR não configurado)"
echo ""

# 5. Verificar eventos de erro
print_header "5️⃣  Verificando Eventos de Erro"
echo "----------------------------------------"
kubectl get events --all-namespaces --field-selector type=Warning --sort-by='.lastTimestamp' | tail -10 || true
echo ""

# 6. Verificar descrição das apps em erro
print_header "6️⃣  Detalhes das Aplicações com Problemas"
echo "----------------------------------------"

# Pegar apps que não estão Healthy
UNHEALTHY=$(kubectl get applications -n argocd --no-headers | grep -v Healthy | awk '{print $1}')

if [ -n "$UNHEALTHY" ]; then
    for app in $UNHEALTHY; do
        echo ""
        echo "🔍 Detalhes da aplicação: $app"
        echo "----------------------------------------"
        kubectl describe application "$app" -n argocd | grep -A 20 "Status:" || true
        
        # Verificar condições específicas
        CONDITIONS=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.conditions}' 2>/dev/null)
        if [ -n "$CONDITIONS" ]; then
            echo "Condições: $CONDITIONS"
        fi
        echo ""
    done
else
    print_ok "Todas as aplicações estão saudáveis!"
fi
echo ""

# 7. Resumo e próximos passos
print_header "📋 RESUMO E PRÓXIMOS PASSOS"
echo "========================================"
echo ""

# Contar apps saudáveis vs problemáticas
TOTAL=$(kubectl get applications -n argocd --no-headers | wc -l)
HEALTHY=$(kubectl get applications -n argocd --no-headers | grep -c Healthy || echo 0)
PROBLEMS=$((TOTAL - HEALTHY))

print_ok "Total de aplicações: $TOTAL"
print_ok "Aplicações saudáveis: $HEALTHY"

if [ $PROBLEMS -gt 0 ]; then
    print_error "Aplicações com problemas: $PROBLEMS"
    echo ""
    echo "Para continuar monitorando, execute:"
    echo "  kubectl get applications -n argocd -w"
    echo ""
    echo "Para forçar sync de todas as apps:"
    echo "  for app in $(kubectl get applications -n argocd -o jsonpath='{.items[*].metadata.name}'); do"
    echo "    kubectl patch application \$app -n argocd -p '{\"operation\":\"sync\"}' --type=merge"
    echo "  done"
    echo ""
    echo "Se o problema persistir, verifique:"
    echo "  1. Se o AKS tem acesso ao ACR (az aks update --attach-acr)"
    echo "  2. Se os charts Helm estão acessíveis"
    echo "  3. Logs: kubectl logs -n argocd deployment/argocd-application-controller"
else
    print_ok "Todas as aplicações estão saudáveis! 🎉"
    echo ""
    echo "Acesse o ArgoCD:"
    echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "  https://localhost:8080"
fi

echo ""
echo "========================================"
