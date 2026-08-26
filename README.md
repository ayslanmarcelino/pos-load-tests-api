# Rails Load Testing Demo

Projeto didático para demonstração de **Teste de Carga (Load Testing)**, desenvolvido
para o seminário de VV&T (Verificação, Validação e Teste de Software) — Pós-Graduação
em Engenharia de Software, Centro Universitário CESMAC.

## Objetivo

Este projeto **não é uma aplicação de produção**. É uma API Ruby on Rails simples,
organizada e 100% reproduzível, criada para demonstrar na prática:

- Teste de carga, concorrência, latência e throughput;
- As métricas p95 / p99 e taxa de erros;
- Um gargalo de aplicação real: o problema de **N+1 queries**;
- Como resolver esse gargalo com **eager loading**;
- Como comparar objetivamente a performance **antes e depois** de uma otimização;
- Como a configuração do Puma (workers/threads) afeta a capacidade da aplicação.

A mensagem central da demonstração:

> Uma aplicação estar funcional não significa que ela continuará funcionando
> adequadamente quando submetida a carga. Testes de carga permitem medir o
> comportamento do sistema, encontrar gargalos e verificar objetivamente se
> requisitos de performance continuam sendo atendidos.

## Arquitetura

```text
k6
 ↓
Puma
 ↓
Ruby on Rails API
 ↓
ActiveRecord
 ↓
PostgreSQL
```

O k6 simula vários usuários (VUs — *virtual users*) acessando a aplicação
simultaneamente, para observar como Puma, Rails e PostgreSQL se comportam sob carga.

## Stack

- Ruby 3.4 + Rails 8.1 (API only)
- PostgreSQL 16
- Puma
- Docker / Docker Compose
- k6 para os testes de carga

## Domínio da aplicação

Duas entidades simples:

```ruby
class Company < ApplicationRecord
  has_many :users
end

class User < ApplicationRecord
  belongs_to :company
  # índice único em email, índice em company_id
end
```

Massa de dados do seed: **500 companies** e **20.000 users**, distribuídos
ciclicamente entre as empresas, inseridos com `insert_all` (seed completo em
~3.5s, em vez de minutos com `Company.create!` um a um).

## Como rodar

### Opção A — Docker (recomendado)

```bash
docker compose up --build
```

Em outro terminal:

```bash
docker compose exec web bin/rails db:prepare
docker compose exec web bin/rails db:seed
```

Ou, de forma resumida, usando o Makefile:

```bash
make setup
```

### Opção B — Local (Ruby/PostgreSQL instalados na máquina)

```bash
bundle install
bin/rails db:prepare
bin/rails db:seed
bin/rails server
```

Por padrão a aplicação usa o socket local do PostgreSQL (usuário do sistema
operacional). Se precisar de host/usuário/senha customizados, copie `.env.example`
para `.env` e ajuste `DB_HOST`, `DB_USERNAME`, `DB_PASSWORD`.

## Criando o banco

```bash
bin/rails db:prepare   # cria o banco e roda as migrations
```

## Executando os seeds

```bash
bin/rails db:seed
```

Gera 500 companies e 20.000 users (`db/seeds.rb`, usando `insert_all` em lotes).

## Endpoints

| Método | Rota                     | Descrição                                   |
|--------|---------------------------|----------------------------------------------|
| GET    | `/health`                 | Baseline — não faz nenhuma query            |
| GET    | `/api/v1/users/slow`      | Lista users **com problema de N+1**         |
| GET    | `/api/v1/users/fast`      | Lista users **com eager loading**           |

Parâmetro opcional em `/slow` e `/fast`:

```text
?limit=N   # padrão 500, máximo 1000 (valores maiores são truncados para 1000)
```

Toda resposta inclui os headers de diagnóstico:

```text
X-Response-Time: tempo de processamento da requisição, em ms
X-SQL-Queries: número de queries SQL executadas durante a requisição
```

(implementado em `app/controllers/application_controller.rb`, via
`ActiveSupport::Notifications.subscribe("sql.active_record")`)

## O problema N+1

`GET /api/v1/users/slow` (`app/controllers/api/v1/users_controller.rb`) busca os
users e, para cada um, acessa `user.company.name`:

```ruby
users = User.limit(query_limit)
users.map { |user| { id: user.id, ..., company: user.company.name } }
```

Como a associação `:company` não foi pré-carregada, o Rails dispara **uma query
adicional por usuário**. Com `limit=500`, isso é **1 query de users + 500 queries
de companies = 501 queries** por requisição (confirmado com o header
`X-SQL-Queries: 501`).

No log (`log/development.log`, com `config.log_level = :debug`), o padrão fica
visível:

```text
User Load (0.5ms)  SELECT "users".* FROM "users" LIMIT 500
Company Load (0.2ms)  SELECT "companies".* FROM "companies" WHERE "companies"."id" = 488 LIMIT 1
Company Load (0.2ms)  SELECT "companies".* FROM "companies" WHERE "companies"."id" = 489 LIMIT 1
Company Load (0.2ms)  SELECT "companies".* FROM "companies" WHERE "companies"."id" = 490 LIMIT 1
...
```

## Endpoint Slow

```http
GET /api/v1/users/slow?limit=500
```

Propositalmente ruim — existe só para demonstrar o N+1 (comentário explicativo
no código-fonte, em `app/controllers/api/v1/users_controller.rb`).

## Endpoint Fast

```http
GET /api/v1/users/fast?limit=500
```

Mesma estrutura de resposta, porém resolve o N+1 com eager loading:

```ruby
users = User.includes(:company).limit(query_limit)
```

Isso reduz a requisição para **2 queries** (1 para users + 1 `WHERE id IN (...)`
para todas as companies necessárias), independente da quantidade de usuários.

## Como instalar k6

- **Linux (binário estático, sem privilégios de root):**

  ```bash
  curl -sL -o k6.tar.gz https://github.com/grafana/k6/releases/download/v0.54.0/k6-v0.54.0-linux-amd64.tar.gz
  tar -xzf k6.tar.gz
  mv k6-v0.54.0-linux-amd64/k6 ~/.local/bin/k6
  ```

- **macOS:** `brew install k6`
- **Windows:** `choco install k6` ou `winget install k6`
- Documentação oficial: <https://grafana.com/docs/k6/latest/set-up/install-k6/>

## Executando teste de carga

Estrutura da pasta `load_tests/`:

```text
load_tests/
  health.js   # baseline, 50 VUs / 30s
  slow.js     # /api/v1/users/slow, 50 VUs / 30s
  fast.js     # /api/v1/users/fast, 50 VUs / 30s (mesma carga de slow.js)
  ramp.js     # ramp test — endpoint escolhido via ENDPOINT=
```

```bash
k6 run load_tests/health.js
k6 run load_tests/slow.js
k6 run load_tests/fast.js
```

Ou via Makefile: `make test-health`, `make test-slow`, `make test-fast`.

## Ramp Test

Teste principal da apresentação: aumenta gradualmente o número de VUs em estágios
para descobrir até que nível de concorrência a aplicação atende ao requisito de
performance definido.

```bash
ENDPOINT=/api/v1/users/slow k6 run load_tests/ramp.js
ENDPOINT=/api/v1/users/fast k6 run load_tests/ramp.js
```

Estágios (`load_tests/ramp.js`):

```text
10 → 25 → 50 → 100 → 200 → 300 VUs, depois volta a 0
15s em cada estágio (10s no encerramento)
```

`BASE_URL` (padrão `http://localhost:3000`) e `ENDPOINT` são configuráveis por
variável de ambiente.

## Métricas

Principais métricas do k6:

| Métrica            | O que significa                                                  |
|---------------------|-------------------------------------------------------------------|
| `http_reqs`         | Total de requisições HTTP feitas                                  |
| `http_req_duration` | Tempo de resposta de cada requisição (inclui avg, med, p90-p99)  |
| `http_req_failed`   | Percentual de requisições que falharam                            |
| `iterations`        | Quantas vezes o script default() rodou por completo               |
| `vus`               | Usuários virtuais ativos no momento                                |
| `vus_max`           | Máximo de VUs configurado no teste                                 |

## Latência

Latência é o tempo entre o envio da requisição e o recebimento da resposta.
`http_req_duration` reporta essa distribuição em várias estatísticas:

- **avg** — média simples de todas as requisições;
- **med** (p50) — metade das requisições foi mais rápida que esse valor;
- **p(90)**, **p(95)**, **p(99)** — percentis: veja a seção seguinte.

Olhar só a média pode esconder requisições muito lentas — uma cauda longa de
requisições ruins pode "desaparecer" numa média dominada por requisições rápidas.

## Throughput

```text
Throughput = quantidade de trabalho processada por unidade de tempo.
```

No contexto desta demonstração: **requests por segundo** (`http_reqs` dividido
pela duração do teste). Quanto maior o throughput mantendo latência e taxa de
erro aceitáveis, maior a capacidade real do sistema.

## p95

```text
p95 = 450 ms

Significa que 95% das requisições responderam em até aproximadamente 450 ms.
Os 5% restantes foram mais lentos.
```

## p99

Mesma lógica do p95, porém olhando para os 1% de requisições mais lentas —
geralmente as que mais impactam a experiência de usuários "azarados" ou casos de
borda (ex.: uma company com cache frio, contenção de lock, GC pausando a thread).

## Thresholds

Um threshold é um requisito objetivo de performance. Todos os scripts usam:

```javascript
thresholds: {
  http_req_failed: ['rate<0.01'],   // menos de 1% de erros
  http_req_duration: ['p(95)<500'], // 95% das respostas em menos de 500ms
}
```

Exemplo de leitura:

```text
Requisito:  95% das requisições precisam responder em menos de 500ms.
            Menos de 1% das requisições podem falhar.

Resultado:  p95 = 350ms, errors = 0%  → PASS
Resultado:  p95 = 1.2s,  errors = 3%  → FAIL
```

## Comparando Slow vs Fast

Resultados obtidos executando `k6 run load_tests/slow.js` e
`k6 run load_tests/fast.js` (50 VUs, 30s, `limit` padrão = 500, 1 worker Puma / 5
threads, banco com 500 companies / 20.000 users, notebook de desenvolvimento
local — **valores reais, obtidos executando os testes; sua máquina terá números
diferentes**):

| Métrica             |          Slow (N+1) |    Fast (includes) |
|----------------------|---------------------:|--------------------:|
| VUs                  |                   50 |                  50 |
| Requests/s           |                 1.68 |                56.4 |
| Latência média (avg) |               22.8 s |             875 ms |
| p95                  |               29.9 s |              1.03 s |
| Error rate           |                  0 % |                 0 % |
| Queries por request  |    501 (1 + 1/user)  |                   2 |

Com apenas 50 usuários simultâneos e a configuração padrão de Puma (1 worker, 5
threads), o N+1 já derruba o throughput em **mais de 30x** e multiplica a
latência em mais de **25x** — mesma API, mesmos dados, mesma carga.

> Re-execute com `make test-slow` / `make test-fast` (ou os comandos `k6 run`
> acima) e atualize esta tabela com os números da sua máquina antes da
> apresentação.

## Puma

Configuração em `config/puma.rb`:

```ruby
threads_count = ENV.fetch("RAILS_MAX_THREADS", 5)
threads threads_count, threads_count

workers ENV.fetch("WEB_CONCURRENCY", 1)
```

```bash
WEB_CONCURRENCY=1 RAILS_MAX_THREADS=5 bin/rails server
WEB_CONCURRENCY=2 RAILS_MAX_THREADS=5 bin/rails server
WEB_CONCURRENCY=4 RAILS_MAX_THREADS=5 bin/rails server
```

> Em `development`, `config.enable_reloading = true` já funciona normalmente com
> múltiplos workers neste projeto (não é necessário `preload_app!`). Se notar
> comportamento inconsistente com `WEB_CONCURRENCY` alto em sua máquina, prefira
> testar cenários de múltiplos workers via Docker Compose, que isola melhor o
> ambiente.

## Workers e Threads

- **Workers**: processos separados do Puma. Cada um tem seu próprio processo
  Ruby (própria GVL) e seu próprio connection pool do ActiveRecord. Mais workers
  = mais paralelismo real de CPU, ao custo de mais memória.
- **Threads**: dentro de cada worker, várias threads atendem requisições
  concorrentemente. Como Ruby MRI tem uma GVL (*Global VM Lock*), threads ajudam
  principalmente quando a requisição espera por I/O (ex.: banco de dados) — que é
  exatamente o caso do `/slow` e do `/fast`.

## Connection Pool

```yaml
pool: <%= ENV.fetch("RAILS_MAX_THREADS", 5) %>
```

Cada **worker** do Puma tem seu próprio pool de conexões do ActiveRecord, com
tamanho igual ao número de **threads** daquele worker (cada thread pode precisar
de uma conexão simultânea com o banco). Ou seja:

```text
conexões no PostgreSQL ≈ Puma workers × RAILS_MAX_THREADS
```

Com `WEB_CONCURRENCY=4` e `RAILS_MAX_THREADS=5`, a aplicação pode abrir até 20
conexões simultâneas com o PostgreSQL. É importante que
`max_connections` do PostgreSQL comporte esse total (o padrão do Postgres, 100,
é suficiente para os cenários deste projeto).

## Experimentos sugeridos

- Repetir o ramp test alterando apenas `WEB_CONCURRENCY` e comparar o ponto de
  degradação.
- Rodar `slow.js` e `fast.js` variando `?limit=` (ex.: 100, 500, 1000) para ver
  como o N+1 escala linearmente com a quantidade de registros.

## Roteiro da demonstração

1. Mostramos a API funcionando (`GET /health`).
2. Explicamos que funcionar não significa ser performático.
3. Abrimos `/api/v1/users/slow` e rodamos `k6 run load_tests/slow.js`.
4. Mostramos as métricas do k6 e, em paralelo, os logs do Rails com várias
   `Company Load`.
5. Explicamos o problema de N+1 e mostramos o código
   (`User.limit(500)` seguido de `user.company.name` no loop).
6. Mostramos a solução — `User.includes(:company).limit(500)` — e rodamos
   exatamente o mesmo teste contra `/fast`.
7. Comparamos requests/s, avg, p95, p99 e error rate entre os dois.
8. Executamos o ramp test (`ENDPOINT=/api/v1/users/fast k6 run load_tests/ramp.js`)
   e identificamos aproximadamente em qual nível de VUs a aplicação deixa de
   atender ao requisito `p95 < 500ms` / `error rate < 1%`.
9. Concluímos: teste de carga não serve só para descobrir "quantos usuários o
   sistema aguenta" — ele ajuda a encontrar gargalos, problemas de banco,
   problemas de concorrência, limitações de infraestrutura e regressões de
   performance antes que cheguem à produção.

## Critério principal da demonstração

```text
Requisito: p95 < 500ms  e  error rate < 1%
```

Pergunta que o ramp test responde:

> Até qual nível de concorrência nossa aplicação consegue atender esse requisito?

Exemplo conceitual do resultado (a tabela real deve ser preenchida ao vivo, com
`ENDPOINT=/api/v1/users/fast k6 run load_tests/ramp.js`):

| VUs  | Resultado |
|------|-----------|
| 10   | ?         |
| 25   | ?         |
| 50   | ?         |
| 100  | ?         |
| 200  | ?         |
| 300  | ?         |

## Load Test vs Stress Test vs Spike Test vs Soak Test

- **Load Test** — avalia o comportamento sob uma carga esperada (ex.: 100
  usuários simultâneos), incluindo o ramp test que sobe a carga em degraus para
  encontrar até que nível o requisito de performance continua sendo atendido.
  Implementado em `slow.js` / `fast.js` / `health.js` / `ramp.js`.
- **Stress Test** — aumenta a carga muito além do esperado até o sistema
  começar a falhar ou degradar significativamente, para descobrir o teto real
  de capacidade. Não implementado neste projeto — apenas conceito.
- **Spike Test** — simula um aumento repentino e abrupto de tráfego (ex.: 10 →
  500 usuários quase instantaneamente). Não implementado neste projeto — apenas
  conceito.
- **Soak Test** — mantém uma carga constante por um período prolongado, para
  identificar problemas que só aparecem com o tempo (memory leak, connection
  leak, degradação gradual). Não implementado neste projeto — apenas conceito.

Este projeto implementa apenas **Load Test** (incluindo o ramp test como forma
de medir a capacidade dentro de um teste de carga). Stress, Spike e Soak Test
são apresentados aqui só como conceito, sem execução nem valores.

## Testes automatizados

```bash
bin/rails test
```

Cobrem: `/health` retorna 200; `/slow` e `/fast` retornam 200; ambos retornam
estruturas equivalentes; o limite padrão (500) e o limite máximo (1000) são
respeitados; `/fast` executa menos queries que `/slow`.

## Estrutura do projeto

```text
app/controllers/application_controller.rb   # headers X-Response-Time / X-SQL-Queries
app/controllers/health_controller.rb
app/controllers/api/v1/users_controller.rb  # /slow e /fast
app/models/company.rb
app/models/user.rb
db/seeds.rb                                  # 500 companies, 20k users, insert_all
load_tests/                                  # scripts k6
config/puma.rb                               # workers/threads configuráveis
docker-compose.yml
Dockerfile
Makefile
```
