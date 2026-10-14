## Этап 5. Хранилище для Postgres

Замени эфемерный Postgres на `StatefulSet` с `PersistentVolumeClaim`. Убедись, что данные переживают удаление пода.

**Приёмка:**

- записал строку в базу, удалил под Postgres, после перезапуска строка на месте
- объяснить, почему обычному Deployment с Postgres нельзя просто поставить `replicas: 3`


## Выполнение

Переписал deployment под стейтфулл сэт, добавил deployment воркера и развернул

Затем пробросил порт при помощи комманды

kubectl port-forward service/api 8000:8000

Зашел на приложение и отправил пост запрос ивента, а затем получил ивенты из базы гет запросом(все через свагер)

```
curl -X 'GET' \
  'http://localhost:8000/events' \
  -H 'accept: */*'

{
  "source": "db",
  "events": [
    {
      "id": 1,
      "name": "name",
      "payload": {
        "additionalProp1": {}
      },
      "created_at": "2026-09-19T16:35:28.668598+00:00"
    }
  ]
}

```

Затем убил поду постгреса

```bash
kubectl get pods
NAME                      READY   STATUS    RESTARTS   AGE
api-6f9c79bbf4-l9dk6      1/1     Running   0          16m
api-6f9c79bbf4-qpjj9      1/1     Running   0          16m
api-6f9c79bbf4-z5vdk      1/1     Running   0          16m
postgres-0                1/1     Running   0          16m
redis-c46d5dffc-zq246     1/1     Running   0          16m
worker-54d9665476-bsd8k   1/1     Running   0          16m
worker-54d9665476-gnz6v   1/1     Running   0          16m
worker-54d9665476-gqbdw   1/1     Running   0          16m

kubectl delete pod postgres-0
pod "postgres-0" deleted from default namespace

kubectl get pods
NAME                      READY   STATUS    RESTARTS   AGE
api-6f9c79bbf4-l9dk6      1/1     Running   0          17m
api-6f9c79bbf4-qpjj9      1/1     Running   0          17m
api-6f9c79bbf4-z5vdk      1/1     Running   0          17m
postgres-0                1/1     Running   0          4s
redis-c46d5dffc-zq246     1/1     Running   0          17m
worker-54d9665476-bsd8k   1/1     Running   0          17m
worker-54d9665476-gnz6v   1/1     Running   0          17m
worker-54d9665476-gqbdw   1/1     Running   0          17m
```

После этого снова отправил гет запрос

и получил

```
curl -X 'GET' \
  'http://localhost:8000/events' \
  -H 'accept: */*'

{
  "source": "db",
  "events": [
    {
      "id": 1,
      "name": "name",
      "payload": {
        "additionalProp1": {}
      },
      "created_at": "2026-09-19T16:35:28.668598+00:00"
    }
  ]
}

```

Обычному Deployment технически можно поставить replicas: 3, но три экземпляра PostgreSQL не станут автоматически единой отказоустойчивой базой. Если у каждого Pod будет своё хранилище, то это будут три независимые базы с разными данными. Если попытаться использовать один ReadWriteOnce PVC для нескольких Pod'ов, возникнут проблемы с одновременным подключением тома, а совместное использование одного каталога данных несколькими независимыми PostgreSQL-процессами вообще небезопасно. Для нескольких экземпляров PostgreSQL необходимо отдельно настраивать primary/replica-репликацию, выбор лидера, failover и маршрутизацию запросов. StatefulSet даёт стабильные имена и стабильные PVC, но сам по себе репликацию PostgreSQL тоже не создаёт