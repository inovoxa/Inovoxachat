# Deploy do Inovoxachat (Chatwoot v4.15.1) no Coolify

Etapa 1 do projeto: subir o **Chatwoot v4.15.1 oficial, sem customização**, em produção
na VPS via **Coolify**. Branding e integração com a Central vêm em etapas posteriores.

Stack que sobe: **Rails (web)** + **Sidekiq (jobs)** + **PostgreSQL `pgvector` pg16** + **Redis**.
São serviços do próprio Chatwoot — independentes do PostgreSQL do n8n/Central.

## Arquivos desta pasta
- `docker-compose.yaml` — compose de produção (imagem fixada em `chatwoot/chatwoot:v4.15.1`).
- `.env.example` — lista das variáveis a preencher na UI do Coolify.

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
