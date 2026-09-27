`api` не видит Postgres. Пройди по цепочке: DNS, selector у Service, labels у подов, NetworkPolicy. Зайди внутрь пода через `exec` и проверь связь руками.

Написал манифесты и запустил

```bash
kubectl apply -f manifests
deployment.apps/postgres created
service/postgres created
kubectl get pods
NAME                        READY   STATUS    RESTARTS        AGE
postgres-7b4959fd89-krnqd   1/1     Running   0               10s
```

Проверим что все работает

```bash
kubectl get pods
NAME                        READY   STATUS    RESTARTS   AGE
api-debug                   1/1     Running   0          4m5s
postgres-7b4959fd89-krnqd   1/1     Running   0          7m44s
kubectl get svc
NAME                    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
devops-app-api          ClusterIP   10.109.178.61    <none>        8000/TCP   93m
devops-app-postgresql   ClusterIP   None             <none>        5432/TCP   93m
devops-app-redis        ClusterIP   None             <none>        6379/TCP   93m
kubernetes              ClusterIP   10.96.0.1        <none>        443/TCP    165m
postgres                ClusterIP   10.107.177.169   <none>        5432/TCP   7m44s
kubectl get networkpolicy
No resources found in default namespace.
```

Так как нетворк полиси не заданы оно никак влиять не будет

И проверим коннект изнутри пода

```bash
kubectl exec -it api-debug -- sh
# python -c 'import socket; print(socket.gethostbyname("postgres"))'
10.107.177.169
# python - <<'PY' 
import socket
s = socket.create_connection(("postgres", 5432), timeout=3)
print("CONNECTED")
s.close()
PY> > > > > > 
CONNECTED
```

Коннект есть будем его ломать

```bash
kubectl patch service postgres \
  --type=merge \
  -p '{"spec":{"selector":{"app":"broken-postgres"}}}'
service/postgres patched
```

Сделаем снова

```Python
import socket
s = socket.create_connection(("postgres", 5432), timeout=3)
print("CONNECTED")
s.close()
PY> > > > > > 
Traceback (most recent call last):
  File "<stdin>", line 3, in <module>
  File "/usr/local/lib/python3.12/socket.py", line 865, in create_connection
    raise exceptions[0]
  File "/usr/local/lib/python3.12/socket.py", line 850, in create_connection
    sock.connect(sa)
ConnectionRefusedError: [Errno 111] Connection refused
```

Как бы мы искали причину если бы не знали её 

```bash
kubectl describe svc postgres
Name:                     postgres
Namespace:                default
Labels:                   <none>
Annotations:              <none>
Selector:                 app=broken-postgres
Type:                     ClusterIP
IP Family Policy:         SingleStack
IP Families:              IPv4
IP:                       10.107.177.169
IPs:                      10.107.177.169
Port:                     <unset>  5432/TCP
TargetPort:               5432/TCP
Endpoints:                
Session Affinity:         None
Internal Traffic Policy:  Cluster
Events:                   <none>

kubectl get endpointslice \
  -l kubernetes.io/service-name=postgres \
  -o wide
NAME             ADDRESSTYPE   PORTS     ENDPOINTS   AGE
postgres-zl87r   IPv4          <unset>   <unset>     21m
```

Это подтверждает, что Service существует и DNS-имя postgres продолжает резолвиться, но Service не выбрал ни одного Pod в качестве backend.

Причина — selector Service: app=broken-postgres

не совпадает с labels PostgreSQL Pod.

Для исправления вернул правильный selector:

```bash
kubectl patch service postgres \
  --type=merge \
  -p '{"spec":{"selector":{"app":"postgres"}}}'
```
