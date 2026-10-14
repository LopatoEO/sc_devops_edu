## Этап 3. ConfigMap и Secret

Вынеси конфигурацию из манифестов. URL Redis и имя базы — в `ConfigMap`. Пароль Postgres и ключи — в `Secret`. Подключи их двумя способами: через `envFrom` и через volume-mount файлом.

**Приёмка:**

- в манифестах Deployment не осталось ни одного хардкоженного пароля
- смени значение в ConfigMap и объясни, подхватит ли его уже запущенный под; для env и для смонтированного файла ответ разный

## Выполнение

Для начала дописал манифесты секретов для api и pg и конфиг для api, развернул все через комманду

```bash
kubectl -n default apply -f manifests
```

Проверил что поды поднялись

```bash
kubectl -n default get pods
NAME                        READY   STATUS    RESTARTS   AGE
api-5d4dcb5668-g454r        1/1     Running   0          8s
api-5d4dcb5668-vm84c        1/1     Running   0          8s
api-5d4dcb5668-vnw7t        1/1     Running   0          8s
postgres-84c77cb487-25tm5   1/1     Running   0          8s
redis-c46d5dffc-wcdts       1/1     Running   0          8s
```

Запустил проброс портов

```bash
kubectl -n default port-forward service/api 8000:8000
```

Зашел через браузер сначала на api а потом на swagger fastapi проверил что теперь readyz работает

Проверка `/readyz` подтверждает доступность Postgres, но не доказывает обновление переменных из ConfigMap: в `api-config` находятся `REDIS_URL` и `EVENTS_CACHE_TTL`. Прямое сравнение env и файла приведено в дополнительном опыте ниже.

Значения ConfigMap, переданные через envFrom, становятся переменными окружения при создании контейнера. Изменение ConfigMap не изменяет переменные окружения уже запущенного процесса — под необходимо пересоздать. Если ConfigMap подключён как обычный volume, Kubernetes обновляет смонтированный файл в работающем поде без его пересоздания. При этом само приложение должно уметь перечитывать файл, чтобы использовать новое значение. Проверим это.

В `manifests/deployment.yaml` сохранён `envFrom` и добавлены `volumeMounts` контейнера и `volumes` шаблона Pod. ConfigMap `api-config` смонтирован каталогом `/etc/app-config`, в режиме `readOnly: true`, без `subPath`. Ключ `EVENTS_CACHE_TTL` доступен одновременно как env и файл `/etc/app-config/EVENTS_CACHE_TTL`.

```bash
kubectl -n default apply -f manifests
```

Найдем имена подов

```bash
kubectl get pods
```

```text
NAME                   READY   STATUS    RESTARTS   AGE
api-765fb99c49-49h65   1/1     Running   0          49s
api-765fb99c49-fxqqq   1/1     Running   0          49s   10.244.0.49   minikube   <none>           <none>
api-765fb99c49-snpm7   1/1     Running   0          49s   10.244.0.52   minikube   <none>           <none>
```

Найдем переменную в volume

```bash
kubectl -n default exec api-765fb99c49-49h65 -- cat /etc/app-config/EVENTS_CACHE_TTL
```

```text
30
```

Найдем значение этой же переменной в env того же Pod

```bash
kubectl -n default exec api-765fb99c49-49h65 -- printenv EVENTS_CACHE_TTL
```

```text
30
```

Изменим переменную через изменение конфигмапы

```bash
kubectl -n default patch configmap api-config --type=merge -p '{"data":{"EVENTS_CACHE_TTL":"60"}}'
configmap/api-config patched
```

Проверим, что значение в volume изменилось

```bash
kubectl -n default exec api-765fb99c49-49h65 -- cat /etc/app-config/EVENTS_CACHE_TTL
```

```text
60
```

Проверим значение переменной окружения в том же работающем Pod

```bash
kubectl -n default exec api-765fb99c49-49h65 -- printenv EVENTS_CACHE_TTL
```

```text
30
```

Значение в env осталось прежним, потому что переменные окружения формируются при запуске контейнера. Чтобы получить новое значение из ConfigMap через envFrom, Pod нужно пересоздать.

Файл в volume обновился без пересоздания Pod. Если бы приложение умело перечитывать этот файл, его конфигурацию можно было бы менять на лету.
