## Этап 2. Service и связывание по сети

Опубликуй `api` через `Service` типа `ClusterIP`. Подними `postgres` и `redis` своими Deployment и Service. Перенастрой `api` ходить в базу по DNS-имени сервиса, не по IP.

**Приёмка:**

- `api` достучался до Postgres по имени сервиса, а не по IP
- `kubectl port-forward` открывает API в браузере
- объяснить, куда уйдёт трафик, если за Service стоят три пода
- знать разницу между ClusterIP, NodePort и LoadBalancer

## Выполнение

Для начала написал сервисы и манифесты для api pg и redis, все это поместил в папку manifests и развернул коммандами

```bash
kubectl apply -f postgres-deployment.yaml
kubectl apply -f postgres-service.yaml

kubectl apply -f redis-deployment.yaml
kubectl apply -f redis-service.yaml

kubectl apply -f deployment.yaml
kubectl apply -f api-service.yaml
```

Проверим что поднялись сервисы

```bash
kubectl get services
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
api          ClusterIP   10.98.38.15     <none>        8000/TCP   1s
kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP    90m
postgres     ClusterIP   10.102.91.144   <none>        5432/TCP   3m29s
redis        ClusterIP   10.96.254.54    <none>        6379/TCP   3m29s
```

Запустил проброс портов

```bash
kubectl port-forward service/api 8000:8000
```

Зашел через браузер сначала на api а потом на swagger fastapi проверил что теперь readyz работает
```bash
curl -X 'GET' \
  'http://localhost:8000/readyz' \
  -H 'accept: */*'
{
  "status": "ready"
}
```
Если за Service находятся три готовых пода, соответствующих его selector, Service предоставляет для них единую точку входа и распределяет входящие соединения между доступными подами. При падении одного пода он исключается из доступных энпоинтов, а после появления новой готовой реплики она автоматически добавляется.
ClusterIP доступен только внутри кластера, NodePort публикует Service через порт на Kubernetes-нодах, а LoadBalancer предназначен для публикации Service через внешний балансировщик нагрузки.
