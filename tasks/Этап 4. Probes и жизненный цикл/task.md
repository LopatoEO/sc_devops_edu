## Этап 4. Probes и жизненный цикл

Добавь в `api` эндпоинты `/healthz` для liveness и `/readyz` для readiness — последний реально проверяет коннект к Postgres. Пропиши `livenessProbe`, `readinessProbe` и `startupProbe`. Выставь `resources.requests` и `resources.limits` по CPU и памяти.

**Приёмка:**

- сломай `/readyz` — под жив, но выпал из Service, трафик на него не идёт
- сломай `/healthz` — под перезапускается, это видно в `kubectl describe`
- поставь заведомо маленький лимит памяти, поймай `OOMKilled` и покажи его в статусе и событиях пода

## Выполнение

У меня уже реализованы эти эндпоинты так что я начал с того что прописал в манифест пробы и ресурсы

Для начала выставим заведомо недостаточные ресурсы

```yaml
resources:
  requests:
    cpu: 10m
    memory: 16Mi
  limits:
    cpu: 100m
    memory: 32Mi
```

Применил манифесты и получил

```bash
kubectl get pods
NAME                        READY   STATUS              RESTARTS     AGE
api-69dd949d6b-zvt2g        0/1     CrashLoopBackOff    2 (9s ago)   41s
api-ddb89cc88-2vhgx         0/1     ContainerCreating   0            5m25s
api-ddb89cc88-d6f2r         0/1     ContainerCreating   0            5m25s
api-ddb89cc88-kcsvr         0/1     ContainerCreating   0            5m25s
postgres-84c77cb487-gc62k   1/1     Running             0            5m25s
redis-c46d5dffc-jmbc4       1/1     Running             0            5m25s
```

Проверил describe сохранил его рядом в txt файле OOM_crash_report В нем видно что причина падения OOM

Вернул нормальные значения ресурсов и перезапустил

```yaml
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 256Mi
```

Поды поднялись

```bash
kubectl get pods
NAME                        READY   STATUS    RESTARTS   AGE
api-6f9c79bbf4-44l6l        1/1     Running   0          53s
api-6f9c79bbf4-7n2dr        1/1     Running   0          69s
api-6f9c79bbf4-m7rnl        1/1     Running   0          60s
postgres-84c77cb487-gc62k   1/1     Running   0          10m
redis-c46d5dffc-jmbc4       1/1     Running   0          10m
```

Далее решил положить readyz пробу положил сервис постгреса

```bash
kubectl delete -f manifests/postgres-service.yaml
service "postgres" deleted from default namespace
```

Поды выпали из READY

```bash
kubectl get pods
NAME                        READY   STATUS    RESTARTS   AGE
api-6f9c79bbf4-44l6l        0/1     Running   0          10m
api-6f9c79bbf4-7n2dr        0/1     Running   0          10m
api-6f9c79bbf4-m7rnl        0/1     Running   0          10m
postgres-84c77cb487-gc62k   1/1     Running   0          20m
redis-c46d5dffc-jmbc4       1/1     Running   0          20m
```

После поднятия обратно postgres обратно

```bash
kubectl apply -f manifests/postgres-service.yaml
service/postgres created
kubectl get pods
NAME                        READY   STATUS    RESTARTS   AGE
api-6f9c79bbf4-44l6l        1/1     Running   0          11m
api-6f9c79bbf4-7n2dr        1/1     Running   0          11m
api-6f9c79bbf4-m7rnl        1/1     Running   0          11m
postgres-84c77cb487-gc62k   1/1     Running   0          21m
redis-c46d5dffc-jmbc4       1/1     Running   0          21m
```

Теперь надо положить health, по этому сделаем контейнер который будет отдавать 500 по healthz эндпоинту и поменял манифест контейнера

```yaml
containers:
        - name: api
          image: elopato/devops-edu-api:v1.2
          imagePullPolicy: IfNotPresent
```

Измененный эндпоинт

```Python
@app.get("/healthz")
def healthz():
    raise HTTPException(status_code=500, detail="not work")
```

Так как я изменил конфиг Deployment сначала хочет запустить новый под а только потом убить старые и из за этого новый не запускается по startupProbe

```yaml
kubectl get pods
NAME                        READY   STATUS    RESTARTS   AGE
api-6cc4866b87-7ln5z        0/1     Running   0          9s
api-6cc4866b87-v74s4        1/1     Running   0          20s
api-6f9c79bbf4-44l6l        1/1     Running   0          20m
api-6f9c79bbf4-7n2dr        1/1     Running   0          21m
postgres-84c77cb487-gc62k   1/1     Running   0          30m
redis-c46d5dffc-jmbc4       1/1     Running   0          30m
```

Перезапустил конфиг

```yaml
NAME                        READY   STATUS    RESTARTS   AGE
api-7478778c7b-7gm2g        0/1     Running   0          19s
api-7478778c7b-dswxp        0/1     Running   0          19s
api-7478778c7b-spb92        0/1     Running   0          19s
postgres-84c77cb487-gc62k   1/1     Running   0          39m
redis-c46d5dffc-jmbc4       1/1     Running   0          39m
```

для того что проверить liveness probe уберу стартап проб

```yaml
kubectl get pods
NAME                        READY   STATUS    RESTARTS      AGE
api-5559f85d94-cgppn        1/1     Running   1 (25s ago)   57s
api-5559f85d94-cvs5j        1/1     Running   1 (25s ago)   57s
api-5559f85d94-sv44r        1/1     Running   1 (26s ago)   57s
postgres-84c77cb487-gc62k   1/1     Running   0             41m
redis-c46d5dffc-jmbc4       1/1     Running   0             41m
```

Теперь под рестартиться по liveness probe оставил describe в файле lp_crash_report.txt


## kubectl logs и разбор events

Собрал логи и события новой проблемной реплики:

```bash
kubectl -n default logs readiness-demo-57b7f45ff5-22r47 --timestamps
kubectl -n default get events --field-selector involvedObject.name=readiness-demo-57b7f45ff5-22r47 --sort-by=.metadata.creationTimestamp
```

В логах есть `request path=/ status=503`. Прямые запросы к приложению показали `/` → `503`, `/readyz` → `200`; состояние пода — `Ready=True`. Значит, readiness проверяет endpoint, который сообщает о готовности даже при ошибках приложения. Service может направлять трафик на эту реплику. `maxUnavailable: 1` допускает уменьшение числа доступных реплик на одну, но не проверяет корректность ответов приложения.

В events видны `Scheduled`, `Pulled`, `Created`, `Started` и предупреждение `Unhealthy` из-за таймаута readiness. В логах также есть `BrokenPipeError` при записи в закрытое соединение; причина закрытия по этим данным не установлена. На момент сохранения состояния под снова Ready. Вывод о ложной readiness основан на сочетании `/` → `503`, `/readyz` → `200` и `Ready=True`.

После исправления readiness собрал данные новой реплики:

```bash
kubectl -n default logs readiness-demo-7d6cfc7c-47p7f --timestamps
kubectl -n default get events --field-selector involvedObject.name=readiness-demo-7d6cfc7c-47p7f --sort-by=.metadata.creationTimestamp
```

В логах приложение по-прежнему возвращает `503`. Теперь `/readyz` также отвечает `503`, в events после стартового `connection refused` появляется `Unhealthy: HTTP probe failed with statuscode: 503`, а под остаётся `Ready=False`. Readiness обнаруживает проблемную версию. Настройки `maxUnavailable: 0`, `maxSurge: 1` сохраняют старые рабочие реплики во время такого выката.

[Команды, логи и события проблемной версии](scenario-4-broken.txt).
[Команды, логи и события после исправления readiness](scenario-4-fixed.txt).
