После выката половина запросов отдаёт 503. Объясни, как это связано с readinessProbe и `maxUnavailable`.

ЗАпустим чистый deployment

```bash
kubectl apply -f manifests/dep.yml
```

Проблемная версия явно задана в `manifests/broken.yml`: `APP_STATUS=503`, `READINESS_MODE=always`. Команда её выката:

```bash
kubectl apply -f manifests/broken.yml
```

Сценарий приостанавливает rollout при одной старой и одной новой Ready-реплике. Перед измерением проверяются два Ready endpoints. Новая реплика возвращает `/` → 503, `/readyz` → 200, поэтому Service направляет в неё трафик.

| Проверка                            | 200 | 503 | 000 |
| ------------------------------------------- | --: | --: | --: |
| Смешанный состав             |  51 |  49 |   0 |
| После исправления readiness | 100 |   0 |   0 |

`maxUnavailable: 1` разрешает уменьшить число доступных реплик на одну, но не исправляет ложную readiness. В `manifests/fixed-broken.yml` readiness возвращает 503 при `APP_STATUS=503`; `maxUnavailable: 0`, `maxSurge: 1` сохраняют рабочие старые реплики. Новая остаётся NotReady, rollout останавливается. После проверки выполнен успешный откат.

[Полный лог](evidence/new/run.log), [curl mixed](evidence/new/mixed.curl.log), [curl fixed](evidence/new/fixed.curl.log)
[Describe mixed](evidence/new/mixed.describe.txt) соответствует `broken.yml` (`minReadySeconds: 120`); [describe fixed](evidence/new/fixed.describe.txt) — `fixed-broken.yml` (`30`).
