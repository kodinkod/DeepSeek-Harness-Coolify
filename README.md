# DeepSeek Harness на Coolify

Свой образ поверх официального npm-пакета [`@deepseek-ai/dsh`](https://www.npmjs.com/package/@deepseek-ai/dsh), чужих Docker-образов нет.
Флаги для запуска за прокси взяты из
[README web-app](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/bundle/web-app/README.md)
и `docs/user/guide/public-deployments.md` в [deepseek-harness](https://github.com/deepseek-ai/deepseek-harness).

| Файл | Что делает |
|---|---|
| `Dockerfile` | `node:24-bookworm-slim` + git + `npm i -g @deepseek-ai/dsh@$DSH_VERSION`, healthcheck |
| `entrypoint.sh` | `dsh --profile web` с bind на IP контейнера, `--public-url`, `--trusted-host` |
| `docker-compose.yml` | сервис + volumes для `DSH_HOME` (профили, ключи) и `/workspace` |

## Деплой в Coolify

1. **Create New Resource** → этот репозиторий → **Build Pack: Docker Compose**.
2. **Environment Variables** (см. `.env.example`):
   - `PUBLIC_URL=https://dsh.твойдомен.com/`
   - `TRUSTED_HOST=dsh.твойдомен.com`
   - `DSH_VERSION=0.2.1-rc.5` (можно не задавать, это значение по умолчанию)
3. **Domains** для сервиса `dsh`: `https://dsh.твойдомен.com:3080`. Здесь `:3080` указывает Coolify порт контейнера, наружу торчит обычный 443.
4. Deploy. В логах появится строка
   `dsh web: https://dsh.твойдомен.com/?token=...`. Открой эту ссылку: dsh поставит cookie на 30 дней и уберёт токен из URL.
   **После каждого рестарта или редеплоя токен новый**, бери его из логов заново.
5. API-ключ DeepSeek задаётся в UI. Хранится в volume `dsh-home` (`/data/dsh/.credentials.yaml`) и переживает редеплой.

## Почему так

- dsh **не принимает wildcard-bind** (`0.0.0.0`), поэтому entrypoint берёт IP через `hostname -i`. Если у контейнера несколько сетей и Traefik не достучался, задай `DSH_HOST` вручную.
- Traefik сохраняет заголовок `Host`, а `/api` пускает только авторитеты из `--trusted-host`. С чужим `Host` в ответ приходит `403`.
- `--public-url` влияет только на напечатанную ссылку и runtime-контекст, доверия он не даёт.

## Basic auth поверх токена (рекомендую)

Это агент с shell, держать его в интернете только за токеном не стоит. В Coolify добавь в `docker-compose.yml` у сервиса `dsh`:

```yaml
    labels:
      - "traefik.http.middlewares.dsh-auth.basicauth.users=${DSH_BASIC_AUTH}"
      - "traefik.http.routers.<router-name>.middlewares=dsh-auth"
```

- `<router-name>` — имя https-роутера, которое Coolify сгенерировал для сервиса. Его видно в сгенерированных labels на странице ресурса.
- `DSH_BASIC_AUTH` — строка вида `user:$$2y$$...` (знаки `$` удваиваются). Сгенерировать её можно так:
  `htpasswd -nbB user 'пароль' | sed -e 's/\$/\$\$/g'`

Вместо basic auth можно поставить forward auth (Authelia, Authentik и т.п.), если он у тебя уже есть.

## Что проверено

На `0.2.1-rc.5`, в локальном Docker:

- образ собирается, healthcheck доходит до `healthy`;
- в логах печатается `https://<PUBLIC_URL>/?token=...`;
- если подставить заголовок `Host`, как это делает Traefik: `/api` с `TRUSTED_HOST` отдаёт `401` (до входа), с чужим `Host` отдаёт `403`;
- вход по токену отдаёт `303` и cookie, после него страница отдаёт `200`.

Через настоящий Coolify и Traefik этот конфиг не прогонялся.
