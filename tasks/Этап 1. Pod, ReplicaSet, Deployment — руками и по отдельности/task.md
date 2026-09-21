## Этап 1. Pod, ReplicaSet, Deployment — руками и по отдельности

Задеплой только `api`. Без Helm, голым YAML. Напиши три манифеста раздельно: сначала `Pod`, потом `ReplicaSet`, потом `Deployment`. Под каждым убей под через `kubectl delete pod` и посмотри, кто воскреснет, а кто нет.

**Приёмка:**

- `kubectl scale deployment api --replicas=3` поднимает три пода
- удаление одного пода тут же создаёт замену
- объяснить цепочку Deployment → ReplicaSet → Pod через labels

Пометь один под новым label через `kubectl label` так, чтобы он выпал из-под selector ReplicaSet. Что сделает контроллер и сколько подов останется?

## Выполнение 

В начале данного упражнения собрал докер образ приложения api и запушил в docker registry

Для начала я написал pod манифест (лежит в папке manifests) и запустил его при помощи комманды

```bash
kubectl apply -f pod.yaml
```
Далее проверил что он запустился

```bash
kubectl get pods
NAME   READY   STATUS    RESTARTS   AGE
api    1/1     Running   0          2m33s
```

После решил проверить что приложение работает и пробросил порт для проверки

```bash 
kubectl port-forward pod/api 8000:8000
```

В отдельном терминале провел проверки 

```bash 
curl http://localhost:8000/healthz
{"status":"ok"}
curl http://localhost:8000/readyz
{"detail":"Database unavailable"}%  
```

Так как база еще не поднята результат считаю успешным

Удалил под при помощи комманды 

```bash 
kubectl delete pod api
```

Как и ожидалось под просто умер и не восстанавливается

```bash 
kubectl get pods        
No resources found in default namespace.
```

Далее я написал replica-set манифест (лежит в папке manifests) и запустил его при помощи комманды

```bash
kubectl apply -f replica-set.yaml
```
Далее проверил что он запустился

```bash
kubectl get rs
NAME     DESIRED   CURRENT   READY   AGE
api-rs   3         3         3       14s
kubectl get pods                 
NAME           READY   STATUS    RESTARTS   AGE
api-rs-7c8j4   1/1     Running   0          28s
api-rs-n9dcx   1/1     Running   0          28s
api-rs-tn76f   1/1     Running   0          28s
```

Снесу один из подов коммандой

```bash 
kubectl delete pod api-rs-7c8j4
```

Проверим теперь вывод комманд

```bash
kubectl get rs
NAME     DESIRED   CURRENT   READY   AGE
api-rs   3         3         3       70s
kubectl get pods                 
NAME           READY   STATUS    RESTARTS   AGE
api-rs-n9dcx   1/1     Running   0          72s
api-rs-rvgwj   1/1     Running   0          5s
api-rs-tn76f   1/1     Running   0          72s
```
Видим что под удалился и реплика сэт запустил еще один в замену этому

Теперь удалим реплика сет

```bash
kubectl delete rs api-rs
replicaset.apps "api-rs" deleted from default namespace
kubectl get rs          
No resources found in default namespace.
kubectl get pods        
No resources found in default namespace.
```

Видим что вместе с удалением реплика сэта умерли и поды

Далее я написал deployment манифест (лежит в папке manifests) и запустил его при помощи комманды

```bash
kubectl apply -f deployment.yaml 
```

Проверил что все работает

```bash
kubectl get deployment
NAME   READY   UP-TO-DATE   AVAILABLE   AGE
api    3/3     3            3           15s
kubectl get rs                  
NAME             DESIRED   CURRENT   READY   AGE
api-5d4dcb5668   3         3         3       5s
kubectl get pods                
NAME                   READY   STATUS    RESTARTS   AGE
api-5d4dcb5668-87p4h   1/1     Running   0          3s
api-5d4dcb5668-jhz9z   1/1     Running   0          3s
api-5d4dcb5668-mwx7m   1/1     Running   0          3s
```

Далее посмотрел какие label присвоены подам

```bash
kubectl get pods --show-labels
NAME                   READY   STATUS    RESTARTS   AGE     LABELS
api-5d4dcb5668-87p4h   1/1     Running   0          3m40s   app=api,pod-template-hash=5d4dcb5668
api-5d4dcb5668-jhz9z   1/1     Running   0          3m40s   app=api,pod-template-hash=5d4dcb5668
api-5d4dcb5668-mwx7m   1/1     Running   0          3m40s   app=api,pod-template-hash=5d4dcb5668
```

И перезаписал один из label

```bash
kubectl label pod api-5d4dcb5668-mwx7m app=not-api --overwrite
pod/api-5d4dcb5668-mwx7m labeled
kubectl get pods --show-labels                                
NAME                   READY   STATUS    RESTARTS   AGE     LABELS
api-5d4dcb5668-87p4h   1/1     Running   0          6m14s   app=api,pod-template-hash=5d4dcb5668
api-5d4dcb5668-fgs9g   1/1     Running   0          4s      app=api,pod-template-hash=5d4dcb5668
api-5d4dcb5668-jhz9z   1/1     Running   0          6m14s   app=api,pod-template-hash=5d4dcb5668
api-5d4dcb5668-mwx7m   1/1     Running   0          6m14s   app=not-api,pod-template-hash=5d4dcb5668
```

Таким образом увидел что под вывалился из зоны видимости реплика сэта и он поднял еще одну поду

Далее решил увеличить кодичество под у деплоймента, так как в задании было сказано 3 а у меня уже 3 решил поднять 4ую

```bash
kubectl scale deployment api --replicas=4
deployment.apps/api scaled
kubectl get pods --show-labels           
NAME                   READY   STATUS    RESTARTS   AGE    LABELS
api-5d4dcb5668-87p4h   1/1     Running   0          8m6s   app=api,pod-template-hash=5d4dcb5668
api-5d4dcb5668-fgs9g   1/1     Running   0          116s   app=api,pod-template-hash=5d4dcb5668
api-5d4dcb5668-jhz9z   1/1     Running   0          8m6s   app=api,pod-template-hash=5d4dcb5668
api-5d4dcb5668-khqf9   1/1     Running   0          2s     app=api,pod-template-hash=5d4dcb5668
api-5d4dcb5668-mwx7m   1/1     Running   0          8m6s   app=not-api,pod-template-hash=5d4dcb5668
```

Далее уменьшил их до 1

```bash
kubectl scale deployment api --replicas=1
deployment.apps/api scaled
kubectl get pods --show-labels
NAME                   READY   STATUS    RESTARTS   AGE     LABELS
api-5d4dcb5668-jhz9z   1/1     Running   0          9m29s   app=api,pod-template-hash=5d4dcb5668
api-5d4dcb5668-mwx7m   1/1     Running   0          9m29s   app=not-api,pod-template-hash=5d4dcb5668
```

Удалим деплоймент и посмотрим какие поды остались 

```bash 
kubectl delete deployment api
deployment.apps "api" deleted from default namespace
kubectl get pods --show-labels           
NAME                   READY   STATUS    RESTARTS   AGE   LABELS
api-5d4dcb5668-mwx7m   1/1     Running   0          12m   app=not-api,pod-template-hash=5d4dcb5668
```

У нас остался только тот под у которого мы переписали лэйбл

Deployment создаёт ReplicaSet, у которого будет selector на определенные в deployment labels. ReplicaSet затем создаёт Pod'ы из шаблона Deployment, и эти Pod'ы получают этот label.

Deployment управляет ReplicaSet, а ReplicaSet управляет Pod'ами. Deployment создаёт ReplicaSet на основании spec.template, а ReplicaSet создаёт необходимое количество Pod'ов. ReplicaSet определяет подходящие Pod'ы с помощью selector, который сопоставляется с labels Pod'ов.
В моём случае Pod'ы имели label app=api. После изменения одного Pod на app=not-api он перестал соответствовать selector ReplicaSet. ReplicaSet увидел только две подходящие реплики вместо трёх и создал новый Pod с app=api. В результате физически существовало четыре Pod'а: три управляемых ReplicaSet и один выпавший из-под его selector.
При удалении Deployment были удалены его ReplicaSet и подконтрольные им Pod'ы, однако Pod с изменённым label остался, поскольку к этому моменту он уже был отпущен ReplicaSet.