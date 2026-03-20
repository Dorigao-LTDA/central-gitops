# Argo CD

Bootstrap GitOps para o projeto.

## Repo central
Este diretorio deve ser versionado no repo central de GitOps:
- https://github.com/Dorigao-LTDA/central-gitops.git

## Estrutura
- `root-app.yaml`: app-of-apps
- `apps/`: aplicativos por componente

## Uso
- Aplique `root-app.yaml` no namespace `argocd`
- O Argo CD sincroniza os apps em `apps/`
