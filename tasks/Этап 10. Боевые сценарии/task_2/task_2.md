Под в `CrashLoopBackOff`. Достань логи предыдущего запуска через `logs --previous` и найди, что его убивает.

Запустил поду

```bash
kubectl apply -f manifests/crash_pod.yml
pod/crashloop-test created

kubectl get pods
NAME             READY   STATUS   RESTARTS      AGE
crashloop-test   0/1     Error    2 (29s ago)   40s
```

Пойдем в describe сначала 

```bash
kubectl describe pod crashloop-test
Name:             crashloop-test
Namespace:        default
Priority:         0
Service Account:  default
Node:             minikube/192.168.49.2
Start Time:       Sun, 20 Sep 2026 20:35:31 +0300
Labels:           <none>
Annotations:      <none>
Status:           Running
IP:               10.244.0.44
IPs:
  IP:  10.244.0.44
Containers:
  app:
    Container ID:  docker://2035ec7f02a118e7a0b6f3896148c8ff8ccda75069a31257a8086f1b9680e9f3
    Image:         busybox:1.36
    Image ID:      docker-pullable://busybox@sha256:73aaf090f3d85aa34ee199857f03fa3a95c8ede2ffd4cc2cdb5b94e566b11662
    Port:          <none>
    Host Port:     <none>
    Command:
      sh
      -c
      echo "Application starting..."
      echo "FATAL: DATABASE_URL is missing"
      sleep 2
      exit 1
      
    State:          Terminated
      Reason:       Error
      Exit Code:    1
      Started:      Sun, 20 Sep 2026 20:38:39 +0300
      Finished:     Sun, 20 Sep 2026 20:38:41 +0300
    Last State:     Terminated
      Reason:       Error
      Exit Code:    1
      Started:      Sun, 20 Sep 2026 20:37:16 +0300
      Finished:     Sun, 20 Sep 2026 20:37:18 +0300
    Ready:          False
    Restart Count:  5
    Environment:    <none>
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-pbc8v (ro)
Conditions:
  Type                        Status
  PodReadyToStartContainers   True 
  Initialized                 True 
  Ready                       False 
  ContainersReady             False 
  PodScheduled                True 
Volumes:
  kube-api-access-pbc8v:
    Type:                    Projected (a volume that contains injected data from multiple sources)
    TokenExpirationSeconds:  3607
    ConfigMapName:           kube-root-ca.crt
    Optional:                false
    DownwardAPI:             true
QoS Class:                   BestEffort
Node-Selectors:              <none>
Tolerations:                 node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                             node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
Events:
  Type     Reason     Age                  From               Message
  ----     ------     ----                 ----               -------
  Normal   Scheduled  3m35s                default-scheduler  Successfully assigned default/crashloop-test to minikube
  Normal   Pulling    3m34s                kubelet            spec.containers{app}: Pulling image "busybox:1.36"
  Normal   Pulled     3m29s                kubelet            spec.containers{app}: Successfully pulled image "busybox:1.36" in 5.622s (5.622s including waiting). Image size: 4105262 bytes.
  Normal   Created    27s (x6 over 3m28s)  kubelet            spec.containers{app}: Container created
  Normal   Started    27s (x6 over 3m28s)  kubelet            spec.containers{app}: Container started
  Normal   Pulled     27s (x5 over 3m26s)  kubelet            spec.containers{app}: Container image "busybox:1.36" already present on machine and can be accessed by the pod
  Warning  BackOff    24s (x6 over 3m23s)  kubelet            spec.containers{app}: Back-off restarting failed container app in pod crashloop-test_default(838af83a-569d-41da-a415-0eef5a627a6d)
```

Видим что kuber запустил поду и она упала значил можем идти в логи

```bash
kubectl logs crashloop-test --previous
Application starting...
FATAL: DATABASE_URL is missing
```

Видим что контейнер падает с ошибкой, дальше надо смотреть на ошибку и исправлять если бы это был не сделаный мной битый под я бы пошел смотреть в переменные манифеста.