## Этап 6. Rolling update и откат

Выкати новую версию `api` сменой тега образа. Настрой стратегию `RollingUpdate` с `maxUnavailable` и `maxSurge`. Потом сломай выкат намеренно — подсунь битый образ — и откатись через `kubectl rollout undo`.

**Приёмка:**

- во время выката `api` отвечает без единой ошибки; проверь фоновым циклом `curl`
- битый образ не уронил прод, потому что readinessProbe не пустила трафик на сломанные поды
- `kubectl rollout undo` вернул рабочую версию, история видна в `rollout history`

## Выполнение

Для данной задачи буду использовать битый образ который я использовал в этапе 4, для начала запустил все манифесты рабочие

Затем я сделаю новый манифест с битой версией и применю его

Запустил курл в отдельном поде 


```
kubectl
--image=curlimages/curl
--rm -it
-- sh

while true; do
>   printf "%s " "$(date '+%H:%M:%S')"
>   curl -s --max-time 3 -o /dev/null -w "%{http_code}\n" http://api:8000/healthz
>   sleep 0.5
> done
```


Сначала выключил postgres, и получил ответы 000 на запрос, то есть проверил что из READY выпали поды, затем включил postgres сделал apply манифеста и все запросы все равно были 200

Получил такую историю ролаута 

```
kubectl rollout history deployment/api
kubectl rollout undo deployment/api
kubectl rollout status deployment/api
deployment.apps/api 
REVISION  CHANGE-CAUSE
1         <none>
2         <none>

Warning: resource deployments/api was previously managed with 'kubectl apply'. Rolling back will not update the kubectl.kubernetes.io/last-applied-configuration annotation, which may cause unexpected behavior on future 'kubectl apply' operations. Consider using 'kubectl apply' with your previous configuration file instead.
deployment.apps/api rolled back
Waiting for deployment "api" rollout to finish: 0 out of 3 new replicas have been updated...
Waiting for deployment "api" rollout to finish: 1 out of 3 new replicas have been updated...
Waiting for deployment "api" rollout to finish: 1 out of 3 new replicas have been updated...
Waiting for deployment "api" rollout to finish: 1 out of 3 new replicas have been updated...
Waiting for deployment "api" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "api" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "api" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "api" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "api" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "api" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "api" rollout to finish: 1 old replicas are pending termination...
deployment "api" successfully rolled out
```

При обновлении Deployment использовалась стратегия RollingUpdate с maxUnavailable: 0 и maxSurge: 1. Во время выката фоновый под непрерывно отправлял запросы через Service api; все запросы возвращали HTTP 200.
Намеренно сломанная версия приложения запускалась, но не проходила readinessProbe, поэтому на них не шел трафик. Старые Ready поды продолжали обслуживать трафик, и неуспешный rollout не вызвал недоступности API.
После этого выполнил kubectl rollout undo deployment/api. Kubernetes постепенно вернул предыдущую рабочую версию, а kubectl rollout status deployment/api завершился сообщением successfully rolled out. История ревизий доступна через kubectl rollout history deployment/api.