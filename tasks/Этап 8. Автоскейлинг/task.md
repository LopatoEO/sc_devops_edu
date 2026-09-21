## Этап 8. Автоскейлинг

Включи `HorizontalPodAutoscaler` для `api` по CPU. Нагрузи сервис через `hey`, `ab` или простой цикл и поймай момент, когда поды начинают размножаться.

**Приёмка:**

- под нагрузкой `kubectl get hpa` показывает рост реплик
- объяснить, почему без `resources.requests` автоскейлинг по CPU не заведётся вовсе

## Выполнение 

Сначала написал манифест для HPA и развернуть приложение

После надо запустить сервер метрик

```bash
minikube addons enable metrics-server
```

Запустил hey

```bash
kubectl run hey \
  --image=williamyeh/hey \
  --restart=Never \
  --rm -it \
  -- \
  -z 2m \
  -c 50 \
  http://api:8000/events
```


Получил рост количества под

```bash
kubectl get pods
NAME                      READY   STATUS    RESTARTS   AGE
api-6f9c79bbf4-4p9th      1/1     Running   0          98s
api-6f9c79bbf4-85zdq      1/1     Running   0          98s
api-6f9c79bbf4-fxsq9      1/1     Running   0          98s
api-6f9c79bbf4-shfth      1/1     Running   0          83s
api-6f9c79bbf4-zhnzn      1/1     Running   0          11m
hey                       1/1     Running   0          12s
postgres-0                1/1     Running   0          11m
redis-c46d5dffc-bgbpf     1/1     Running   0          11m
worker-54d9665476-gdg8x   1/1     Running   0          11m
worker-54d9665476-nf7ml   1/1     Running   0          11m
worker-54d9665476-q5qxb   1/1     Running   0          11m
```

Вывод get hpa

```bash
kubectl get hpa
NAME   REFERENCE        TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
api    Deployment/api   cpu: 106%/50%   1         5         5          12m
```


Для HPA с метрикой CPU типа Utilization обязательно должен быть задан resources.requests.cpu. Процент CPU рассчитывается относительно запрошенного CPU. Например, если requests.cpu: 100m, а контейнер использует 50m, его utilization составляет 50%. Если requests.cpu не задан, Kubernetes не знает, относительно какого значения вычислять процент загрузки CPU, поэтому HPA не сможет корректно рассчитать необходимое количество реплик по этой метрике.