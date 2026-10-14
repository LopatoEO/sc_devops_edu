## Этап 6. Rolling update и откат

Выкати новую версию `api` сменой тега образа. Настрой стратегию `RollingUpdate` с `maxUnavailable` и `maxSurge`. Потом сломай выкат намеренно — подсунь битый образ — и откатись через `kubectl rollout undo`.

**Приёмка:**

- во время выката `api` отвечает без единой ошибки; проверь фоновым циклом `curl`
- битый образ не уронил прод, потому что readinessProbe не пустила трафик на сломанные поды
- `kubectl rollout undo` вернул рабочую версию, история видна в `rollout history`

## Выполнение

Опыт выполнен со стратегией `maxUnavailable: 0`, `maxSurge: 1`.

Фоновый цикл curl из выполненного сценария:

```bash
kubectl -n default run curl-rollout \
  --image=curlimages/curl:8.12.1 --restart=Never --command -- sh -c '
while true; do
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  code=$(curl -sS --max-time 3 -o /dev/null -w "%{http_code}" http://api:8000/healthz)
  rc=$?
  printf "%s %s %s\n" "$ts" "$code" "$rc"
  sleep 0.5
done'
```

| Фаза                                         | 200 | 000 |
| ------------------------------------------------ | --: | --: |
| Исходная версия                    |  27 |   0 |
| Выкат fix-v1 → fix-v2                      |  81 |   0 |
| Битый образ                            |  83 |   0 |
| Откат образа                          |  30 |   0 |
| Сломанная readiness                     |  85 |   0 |
| Откат readiness                             |  27 |   0 |
| Отключение Postgres                    |  37 |  30 |
| После восстановления Postgres |  27 |   0 |

Во время rollout и откатов ошибок нет. Несуществующий образ дал `ErrImagePull`; в отдельной фазе новая реплика была Running, но readiness возвращала 404 и не пропускала её в трафик. Старые реплики оставались Ready. Оба `kubectl rollout undo` завершились успешно, `/version` подтвердил смену `fix-v1` на `fix-v2`.

`000` с exit code curl 7 относится к отдельному отключению Postgres. После восстановления API снова готов: 3/3.

[Полный лог команд](evidence/new/run.log), [границы фаз](evidence/new/timeline.log) и  [история](evidence/new/recovery.resources.txt). Отдельные curl-логи находятся в том же каталоге.
