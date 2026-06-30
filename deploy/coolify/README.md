# Deploy do Inovoxachat (Chatwoot fork v4.15.1) no Coolify

Subir o **Inovoxachat** (fork do Chatwoot v4.15.1) em produção na VPS via **Coolify**,
usando a **imagem própria da Inovoxa** buildada do código-fonte pelo GitHub Actions.

Stack que sobe: **Rails (web)** + **Sidekiq (jobs)** + **PostgreSQL `pgvector` pg16** + **Redis**.
São serviços do próprio Chatwoot — independentes do PostgreSQL do n8n/Central.

## Arquivos desta pasta
- `docker-compose.yaml` — compose de produção (imagem `ghcr.io/inovoxa/inovoxachat:latest`).
- `.env.example` — lista das variáveis a preencher na UI do Coolify.

## 0. Imagem própria da Inovoxa (GitHub Actions → GHCR)
A imagem é compilada do source pelo workflow `.github/workflows/inovoxa-build.yml` e publicada
em `ghcr.io/inovoxa/inovoxachat`. Antes do primeiro deploy:
1. Em **GitHub → repo Inovoxachat → Actions**, habilite os workflows (se for o 1º uso) e
   rode **"Build Inovoxachat image"** (push na `main` já dispara; ou *Run workflow* manual).
2. Aguarde o build (~20–40 min na 1ª vez; depois o cache acelera). Ao fim, o pacote
   **inovoxachat** aparece em **GitHub → org inovoxa → Packages**.
3. O pacote nasce **privado**. Para o Coolify puxar, escolha uma opção:
   - **(simples)** Package → *Settings* → **Change visibility → Public** (a imagem fica pública).
   - **(privado)** No Coolify, adicione um **Registry/Docker credential** para `ghcr.io`
     (usuário = seu login GitHub, senha = um **PAT** com escopo `read:packages`), e vincule-a
     ao recurso. Mantém a imagem privada.
   > ⚠️ A imagem contém o código Enterprise do Chatwoot (licença comercial). Se for distribuir,
   > prefira manter **privada** ou migrar para a edição CE.

## 1. Gerar os segredos (no seu terminal)
```bash
openssl rand -hex 64   # SECRET_KEY_BASE
openssl rand -hex 16   # ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY
openssl rand -hex 16   # ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
openssl rand -hex 16   # ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT
openssl rand -hex 24   # POSTGRES_PASSWORD
openssl rand -hex 24   # REDIS_PASSWORD
```
Guarde o `SECRET_KEY_BASE` — trocá-lo depois invalida todas as sessões.

## 2. Criar o recurso no Coolify
1. **+ New Resource → Docker Compose**.
2. Origem: repositório **`inovoxa/Inovoxachat`**, branch **`main`**.
3. **Compose file / Base Directory:** `deploy/coolify/docker-compose.yaml`.
4. **Environment Variables:** cole as chaves do `.env.example` e preencha os valores reais
   (inclusive os segredos gerados no passo 1). `FRONTEND_URL` = o domínio HTTPS abaixo.

## 3. Domínio e HTTPS
- Aponte um subdomínio (ex.: `chat.seu-dominio.gov.br`) ao serviço **`rails`**, porta **3000**.
- Habilite HTTPS (Let's Encrypt do Coolify).
- Garanta **upgrade de WebSocket** no proxy (necessário para o realtime/ActionCable).
- `FRONTEND_URL` deve ser exatamente esse domínio (com `https://`, sem barra final).

## 4. Primeiro deploy e preparação do banco
1. Faça o **Deploy**. Aguarde as imagens subirem (`rails`, `sidekiq`, `postgres`, `redis`).
2. **Uma única vez**, no terminal do container `rails` (aba Terminal do Coolify):
   ```bash
   bundle exec rails db:chatwoot_prepare
   ```
   (cria o schema + dados iniciais). Em deploys seguintes, as migrações rodam sozinhas
   pelo entrypoint `docker/entrypoints/rails.sh`.

## 5. Criar o primeiro usuário (super admin)
Com `ENABLE_ACCOUNT_SIGNUP=false`, crie o usuário pelo console:
```bash
bundle exec rails c
```
```ruby
u = User.new(name: 'Admin Inovoxa', email: 'admin@seu-dominio.gov.br',
             password: 'TroqueEstaSenhaForte!1')
u.skip_confirmation!  # dispensa e-mail de confirmação se o SMTP ainda não estiver pronto
u.save!
# acesso ao /super_admin (painel de superadministração):
SuperAdmin.create!(email: u.email, password: 'TroqueEstaSenhaForte!1') rescue nil
```
> Se o SMTP já estiver configurado, pode em vez disso criar a conta pela tela de signup
> (habilitando `ENABLE_ACCOUNT_SIGNUP=true` temporariamente) e depois voltar para `false`.

## 6. Validação (fim da Etapa 1)
- `https://<seu-dominio>/` abre o login do Chatwoot; rodapé/Settings mostram **v4.15.1**.
- Login com o super admin; criar uma **Inbox** de teste.
- Reinicie o serviço `rails` e confirme que os dados persistem (volumes OK).
- `sidekiq` saudável e processando jobs.

## 7. CD automático (commit → deploy)
O workflow `.github/workflows/inovoxa-build.yml` builda a imagem e, ao final, dispara o redeploy
no Coolify (passo *Redeploy no Coolify*). Como o recurso é um compose único, **um** webhook
redeploya tudo (rails+sidekiq+postgres+redis).
1. No Coolify, no recurso, pegue o **endpoint de deploy da API**:
   `https://<seu-coolify>/api/v1/deploy?uuid=<uuid-do-recurso>` e gere um **API token**
   (Coolify → *Keys & Tokens / API Tokens*).
2. No **GitHub → repo → Settings → Secrets and variables → Actions**, crie:
   - `COOLIFY_WEBHOOK` = a URL de deploy acima.
   - `COOLIFY_TOKEN` = o API token (Bearer). *(opcional se a URL já autenticar)*
3. (Opcional) Remova os secrets `PORTAINER_WEBHOOK_*` se não for mais usar o Swarm — os dois
   passos são independentes e cada um só roda se seu secret existir.
> A imagem usa a tag `:latest` com `pull_policy: always`, então o redeploy puxa sempre a build
> mais recente. Para builds imutáveis, fixe uma tag/sha no `docker-compose.yaml`.

## Pontos de atenção
- **pgvector obrigatório** — a imagem do Postgres é `pgvector/pgvector:pg16` (já no compose).
- **3 chaves `ACTIVE_RECORD_ENCRYPTION_*`** — sem elas o 2FA e campos cifrados falham.
- **SMTP** — sem e-mail válido, convites/confirmações não saem; use `skip_confirmation!` no 1º usuário.
- **RAM** — Rails + Sidekiq + Postgres + Redis pedem ~2 GB; confira a capacidade da VPS.
- **Arquivo grande no repo** — `vendor/db/sentiment-analysis.onnx` (~66 MB) gera *warning* no GitHub,
  mas não impede o deploy. Migrar para Git LFS é opcional (etapa futura).

## Próximas etapas (fora do escopo da Etapa 1)
1. Branding/white-label (nome, logo, favicon, cores).
2. Reescrita nativa de **Chamados + Kanban + SLA** como páginas Vue/Rails dentro do fork.
3. Migração do número de WhatsApp do Chatwoot atual (fazer.ai) para este.
4. Reapontar a Central (`CHATWOOT_URL/TOKEN/ACCOUNT_ID`) para o Inovoxachat.
