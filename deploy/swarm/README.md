# Deploy do Inovoxachat no Docker Swarm (Portainer + Traefik) com CD automático

Pipeline completo: **você edita o código → commit/push → GitHub Actions builda a imagem →
o Portainer redeploya na VPS** (Swarm puxa a imagem nova). Roteamento e TLS pelo Traefik.

```
git push (main)  →  Actions builda ghcr.io/inovoxa/inovoxachat:latest  →  webhook Portainer
                 →  docker service update --force (puxa :latest)        →  no ar em chat.inovoxa.com.br
```

## Pré-requisitos na VPS
- Docker **Swarm** ativo; **Traefik** já rodando (entrypoint `websecure` + certresolver `letsencrypt`).
- Rede overlay externa **`inovoxa`** (a do Traefik). Se faltar:
  ```bash
  docker network create --driver overlay --attachable inovoxa
  ```
- **DNS:** registro A de `chat.inovoxa.com.br` → IP público da VPS.
- **Login no GHCR** no node manager (imagem privada):
  ```bash
  docker login ghcr.io -u <seu-usuario-github> -p <PAT com read:packages>
  ```

## 1. Imagem própria (uma vez)
Garanta que o workflow **"Build Inovoxachat image"** já rodou (GitHub → Actions) e publicou
`ghcr.io/inovoxa/inovoxachat:latest`. Veja `../coolify/README.md` seção 0 para detalhes do build/registry.

## 2. Subir o stack no Portainer
1. **Stacks → Add stack → Web editor**. Nome: `inovoxachat`.
2. Cole o conteúdo de `inovoxachat-stack.yml`.
3. Em **Environment variables**, adicione (valores reais; segredos gerados à parte):
   ```
   IMAGE=ghcr.io/inovoxa/inovoxachat:latest
   SECRET_KEY_BASE=...
   FRONTEND_URL=https://chat.inovoxa.com.br
   ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=...
   ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=...
   ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=...
   POSTGRES_USERNAME=postgres
   POSTGRES_PASSWORD=...
   POSTGRES_DATABASE=chatwoot
   REDIS_URL=redis://redis:6379
   REDIS_PASSWORD=...
   ACTIVE_STORAGE_SERVICE=local
   MAILER_SENDER_EMAIL=Inovoxachat <atendimento@inovoxa.com.br>
   SMTP_DOMAIN=inovoxa.com.br
   SMTP_ADDRESS=
   SMTP_PORT=587
   SMTP_USERNAME=
   SMTP_PASSWORD=
   ```
4. **Deploy the stack**. (Garanta que o Portainer tem a credencial do GHCR, ou já fez `docker login` no node.)

> Alternativa por CLI no node manager:
> ```bash
> docker stack deploy -c inovoxachat-stack.yml --with-registry-auth inovoxachat
> ```

## 3. Preparar o banco (uma vez)
No Portainer: **Containers → o container `inovoxachat_rails…` → Console → Connect (/bin/sh)** e rode:
```bash
bundle exec rails db:chatwoot_prepare
```
(ou via CLI: `docker exec -it $(docker ps -q -f name=inovoxachat_rails) bundle exec rails db:chatwoot_prepare`)

## 4. Criar o super admin (sem SMTP ainda)
No mesmo console:
```bash
bundle exec rails c
```
```ruby
u = User.new(name: 'Admin Inovoxa', email: 'admin@inovoxa.com.br', password: 'TroqueJa!Forte1')
u.skip_confirmation!
u.save!
```

## 5. Ligar o CD automático (webhooks)
1. No Portainer, abra o serviço **`inovoxachat_rails`** → aba **Service webhooks** → **Create webhook** → copie a URL.
2. Repita para **`inovoxachat_sidekiq`**.
3. No GitHub (repo Inovoxachat) → **Settings → Secrets and variables → Actions → New repository secret**:
   - `PORTAINER_WEBHOOK_RAILS` = URL do webhook do rails
   - `PORTAINER_WEBHOOK_SIDEKIQ` = URL do webhook do sidekiq
4. Pronto. A partir daí, todo push na `main` que altere o código builda a imagem e, ao final,
   o workflow chama os webhooks → os serviços puxam `:latest` e reiniciam com a versão nova.

> O webhook do Portainer faz `docker service update --force` no serviço, repuxando a imagem.
> Como o stack usa a tag **`latest`**, o redeploy sempre traz o último build.

## Verificação
1. `https://chat.inovoxa.com.br` abre o Chatwoot (certificado válido via Let's Encrypt).
2. Login com o super admin; criar uma Inbox de teste.
3. Editar algo no código → push → ver o run no Actions → em ~minutos o serviço reinicia atualizado.

## Notas
- **Multi-node:** `storage_data` (anexos) é volume local compartilhado entre `rails` e `sidekiq`;
  por isso o stack fixa os serviços no mesmo node (`node.role == manager`). Em vários nodes,
  troque por storage compartilhado (NFS/cluster) e ajuste os `placement.constraints`.
- **Tag `latest` x versão:** `latest` simplifica o CD. Para rollback determinístico, dá para
  usar a tag por commit (`sha-...`) que o workflow também publica, fixando `IMAGE` no stack.
- **HTTP→HTTPS:** assume-se redirect global no seu Traefik; se não houver, adicione um router
  no entrypoint `web` com middleware de redirect.
