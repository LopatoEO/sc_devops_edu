После выката половина запросов отдаёт 503. Объясни, как это связано с readinessProbe и `maxUnavailable`.

Для проверки сценария использовал Deployment с двумя репликами и стратегией RollingUpdate:

Также была настроена readynessProbe, которая проверяла соответсвующий endpoint.

Проблема заключалась в том, что эндпоинт продолжал возвращать 200, даже когда новая версия приложения уже не могла корректно обслуживать пользовательские запросы и возвращала 503.

Из-за этого Kubernetes считал новую реплику готовой и проксировал на него запросы.

Получалась ситуация:

Service балансировал запросы между обеими репликами, поэтому часть запросов попадала на неисправную новую версию и возвращала 503.

Провери состояние Pod можно через:

```
kubectl get pods
```

Проверить endpoints Service:

```
kubectl get endpointslice \
  -l kubernetes.io/service-name=<service-name> \
  -o wide
kubectl get endpointslice \
  -l kubernetes.io/service-name=readiness-demo \
  -o wide
NAME                   ADDRESSTYPE   PORTS   ENDPOINTS                 AGE
readiness-demo-xc8vp   IPv4          8000    10.244.0.48,10.244.0.47   7m10s
```

Проверим deployment

```
kubectl describe deployment readiness-demo
Name:                   readiness-demo
Namespace:              default
CreationTimestamp:      Sun, 20 Sep 2026 21:24:49 +0300
Labels:                 <none>
Annotations:            deployment.kubernetes.io/revision: 1
Selector:               app=readiness-demo
Replicas:               2 desired | 2 updated | 2 total | 2 available | 0 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  1 max unavailable, 0 max surge
Pod Template:
  Labels:  app=readiness-demo
  Containers:
   app:
    Image:      python:3.12-alpine
    Port:       8000/TCP
    Host Port:  0/TCP
    Command:
      python
      -c
      import os
      from http.server import BaseHTTPRequestHandler, HTTPServer
      
      status = int(os.environ.get("APP_STATUS", "200"))
      
      class Handler(BaseHTTPRequestHandler):
          def do_GET(self):
              if self.path == "/readyz":
                  self.send_response(200)
                  self.end_headers()
                  self.wfile.write(b"READY")
                  return
      
              self.send_response(status)
              self.end_headers()
              self.wfile.write(
                  f"APP STATUS: {status}\n".encode()
              )
      
          def log_message(self, format, *args):
              pass
      
      HTTPServer(("0.0.0.0", 8000), Handler).serve_forever()
      
    Readiness:  http-get http://:8000/readyz delay=1s timeout=1s period=2s #success=1 #failure=3
    Environment:
      APP_STATUS:  200
    Mounts:        <none>
  Volumes:         <none>
  Node-Selectors:  <none>
  Tolerations:     <none>
Conditions:
  Type           Status  Reason
  ----           ------  ------
  Available      True    MinimumReplicasAvailable
  Progressing    True    NewReplicaSetAvailable
OldReplicaSets:  <none>
NewReplicaSet:   readiness-demo-677bc5c686 (2/2 replicas created)
Events:
  Type    Reason             Age    From                   Message
  ----    ------             ----   ----                   -------
  Normal  ScalingReplicaSet  8m19s  deployment-controller  Scaled up replica set readiness-demo-677bc5c686 from 0 to 2
```

maxUnavailable: 1 означает, что во время rollout Kubernetes разрешено иметь на одну доступную реплику меньше заданного числа.

При двух репликах Kubernetes может временно оставить только одну старую рабочую реплику. После того как новая реплика проходит readiness, Deployment считает её полноценной заменой и может продолжить удаление старых Pod.

Для более безопасного rollout можно использовать:

```
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0
    maxSurge: 1
```

В таком случае Kubernetes сначала создаёт дополнительную новую реплику и ждёт, пока она станет Ready, и только после этого удаляет старую.

Однако основное исправление — сделать readinessProbe действительно отражающей способность приложения обслуживать пользовательский трафик.
