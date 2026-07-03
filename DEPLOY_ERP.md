# Checklist de Deploy — Módulos ERP (Empresas / CRM / Vendas / etc.)

Guia para publicar e validar as **13 tabelas novas** do ERP embutido no Inovoxachat.
O entrypoint da imagem **NÃO** roda `db:migrate` automaticamente — a migração é manual.

---

## 0. Pré-checagem (antes de qualquer coisa)

- [ ] Backup do banco (Coolify → serviço Postgres → backup, ou `pg_dump`).
      As migrations são reversíveis, mas backup é a rede de segurança.
- [ ] Confirmar que o build da imagem passou:
      GitHub Actions → workflow de build → `ghcr.io/inovoxa/inovoxachat:latest` verde.
- [ ] Anotar o commit publicado: `c64e07c3e` (módulo Vendas, último).

## 1. Redeploy da imagem (Coolify)

- [ ] Coolify → aplicação Inovoxachat → **Redeploy** (puxa `:latest`).
- [ ] Aguardar containers `web` e `worker` subirem (health check verde).

## 2. Migração do banco (manual, dentro do container)

Abrir um shell no container **web** (Coolify → Terminal, ou `docker exec`):

- [ ] Ver o que está pendente:
      ```bash
      RAILS_ENV=production bundle exec rails db:migrate:status | grep down
      ```
      Devem aparecer como `down` (pendentes) as 13 migrations ERP + campos de empresa:
      ```
      20260702120000  Add business fields to companies
      20260702130000  Create equipments
      20260702130001  Create contracts
      20260702130002  Create contract items
      20260702140000  Create invoices
      20260702150000  Create opportunities
      20260702160000  Create projects
      20260702160001  Create project tasks
      20260702170000  Create repair orders
      20260702180000  Create planning shifts
      20260702190000  Create meetings
      20260703120000  Create quotations
      20260703120001  Create quotation lines
      ```
      (As GLPI `2026062512...`/`2026062612...` já devem estar `up` de deploys anteriores.)

- [ ] Rodar a migração:
      ```bash
      RAILS_ENV=production bundle exec rails db:migrate
      ```

- [ ] Confirmar que não sobrou nada `down`:
      ```bash
      RAILS_ENV=production bundle exec rails db:migrate:status | grep down
      ```
      (Saída vazia = tudo migrado.)

## 3. Ativar a feature `companies` na conta

Todos os módulos ERP são gated na feature `companies` (premium, `enabled: false` por padrão).
Sem ela, os endpoints retornam **403** e o menu não aparece.

- [ ] No console Rails, ativar por conta (repita o `id` para cada conta que deve ter ERP):
      ```bash
      RAILS_ENV=production bundle exec rails runner "Account.find(1).enable_features!('companies'); puts 'ok'"
      ```
      > ⚠️ Ative **apenas** nas contas que devem ver o ERP — a feature é o que
      > mantém o isolamento de exposição entre contas.

## 4. Validação funcional (por módulo)

Fazer login numa conta com a feature ativa e verificar o menu lateral + criar 1 registro:

- [ ] **Empresas** — abrir uma empresa; campos CNPJ/status/responsável/telefone/endereço salvam.
- [ ] **CRM → Funil** — criar oportunidade; arrastar entre estágios; "Ganho" gera contrato.
- [ ] **Vendas → Cotações** — criar cotação, adicionar linha, ver total; **Confirmar** gera Contrato.
- [ ] **Projetos** — criar projeto e tarefa (arrastar no Kanban).
- [ ] **Reparos** — criar ordem; mover de coluna.
- [ ] **Planejamento** — criar turno; navegar por dia.
- [ ] **Calendário → Reuniões** — criar reunião; aparece na grade da semana.
- [ ] **Painel de Locação** — cards agregam os números das listas.

## 5. Validação de isolamento entre contas (CRÍTICO)

- [ ] Logar na **conta B** (sem a feature, ou outra conta com feature):
      confirmar que **não** vê empresas/cotações/contratos da **conta A**.
- [ ] Tentar `GET /api/v1/accounts/<A>/quotations` autenticado como usuário da conta B → **403/404**.

## 6. Validação do Copilot

- [ ] Abrir o Copilot numa conta com a feature e perguntar:
      - "Quais cotações estão pendentes?" → usa `quotations_lookup`.
      - "Contratos a vencer nos próximos 30 dias?" → usa `contracts_lookup`.
      - "Oportunidades abertas?" → usa `opportunities_lookup`.

---

## Rollback (se algo falhar na migração)

As migrations são reversíveis (`create_table`/`add_column`). Para desfazer as ERP e
voltar ao estado anterior ao módulo Empresas:

```bash
# desce até imediatamente antes de "add_business_fields_to_companies"
RAILS_ENV=production bundle exec rails db:migrate:down VERSION=20260703120001
RAILS_ENV=production bundle exec rails db:migrate:down VERSION=20260703120000
# ... repetir na ordem inversa até 20260702120000, se necessário
```

Ou reverter o redeploy no Coolify para a imagem anterior e restaurar o backup do passo 0.

## Notas

- **Tabelas criadas** (todas com `account_id` para multi-tenant):
  `equipments`, `contracts`, `contract_items`, `invoices`, `opportunities`,
  `projects`, `project_tasks`, `repair_orders`, `planning_shifts`, `meetings`,
  `quotations`, `quotation_lines` + colunas de negócio em `companies`.
- **schema.rb não é usado no deploy** (a imagem migra incrementalmente); por isso
  as migrations ERP não estão em `db/schema.rb` — é esperado.
- Se o `db:migrate` reclamar de migration pendente de outro deploy, rode primeiro
  `db:migrate:status` e migre tudo de uma vez (a ordem por timestamp é respeitada).
