Под застрял в `Pending`. Найди причину: не хватает ресурсов ноды, не привязался PVC, не сошёлся nodeSelector.


1. Не хватает ресурсов

Собрал манифест поды `overload_pod.yml` с заведомо завышенными требованиями по ресурсам

Проверил что он не запустился

```bash
kubectl get pods
NAME                READY   STATUS    RESTARTS   AGE
pending-resources   0/1     Pending   0          97s
```

Запустим describe

```bash
kubectl describe pod pending-resources
Name:             pending-resources
Namespace:        default
Priority:         0
Service Account:  default
Node:             <none>
Labels:           <none>
Annotations:      <none>
Status:           Pending
IP:
IPs:              <none>
Containers:
  app:
    Image:      nginx:alpine
    Port:       <none>
    Host Port:  <none>
    Requests:
      cpu:        100
      memory:     100Gi
    Environment:  <none>
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-5x6kv (ro)
Conditions:
  Type           Status
  PodScheduled   False
Volumes:
  kube-api-access-5x6kv:
    Type:                    Projected (a volume that contains injected data from multiple sources)
    TokenExpirationSeconds:  3607
    ConfigMapName:           kube-root-ca.crt
    Optional:                false
    DownwardAPI:             true
QoS Class:                   Burstable
Node-Selectors:              <none>
Tolerations:                 node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                             node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
Events:
  Type     Reason            Age    From               Message
  ----     ------            ----   ----               -------
  Warning  FailedScheduling  3m33s  default-scheduler  0/1 nodes are available: 1 Insufficient cpu, 1 Insufficient memory. no new claims to deallocate, preemption: 0/1 nodes are available: 1 Preemption is not helpful for scheduling.
```

В describe вижу FailedScheduling, scheduler не смог подобрать ноду по причине недостаточности ресурсов на нодах.

Для исправления надо пересмотреть запросы на ресурсы в манифесте.

2. Не привязался PVC

Написал два манифеста для PVC и поды и запустил

```bash
kubectl apply -f manifests/pvc.yml
persistentvolumeclaim/broken-pvc created
kubectl apply -f manifests/pvc_pod.yml
pod/pending-pvc created
```

Проверим что пода и pvc не запустились

```bash
kubectl get pods
NAME          READY   STATUS    RESTARTS   AGE
pending-pvc   0/1     Pending   0          107s

kubectl get pvc
NAME         STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS          VOLUMEATTRIBUTESCLASS   AGE
broken-pvc   Pending                                      nonexistent-storage   <unset>                 3m55s
```

Посмотрим describe пода

```bash
kubectl describe pod pending-pvc
Name:             pending-pvc
Namespace:        default
Priority:         0
Service Account:  default
Node:             <none>
Labels:           <none>
Annotations:      <none>
Status:           Pending
IP:
IPs:              <none>
Containers:
  app:
    Image:        nginx:alpine
    Port:         <none>
    Host Port:    <none>
    Environment:  <none>
    Mounts:
      /data from data (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-v7kpk (ro)
Conditions:
  Type           Status
  PodScheduled   False
Volumes:
  data:
    Type:       PersistentVolumeClaim (a reference to a PersistentVolumeClaim in the same namespace)
    ClaimName:  broken-pvc
    ReadOnly:   false
  kube-api-access-v7kpk:
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
  Type     Reason            Age   From               Message
  ----     ------            ----  ----               -------
  Warning  FailedScheduling  3m6s  default-scheduler  0/1 nodes are available: pod has unbound immediate PersistentVolumeClaims. not found
```

Видим что PVC недоступен и идем в describe pvc

```bash
kubectl describe pvc broken-pvc
Name:          broken-pvc
Namespace:     default
StorageClass:  nonexistent-storage
Status:        Pending
Volume:
Labels:        <none>
Annotations:   <none>
Finalizers:    [kubernetes.io/pvc-protection]
Capacity:
Access Modes:
VolumeMode:    Filesystem
Used By:       pending-pvc
Events:
  Type     Reason              Age                  From                         Message
  ----     ------              ----                 ----                         -------
  Warning  ProvisioningFailed  8s (x18 over 4m17s)  persistentvolume-controller  storageclass.storage.k8s.io "nonexistent-storage" not found
```

Видим что проблема с storage class

В данном случае просто удаляем сам storage class из манифеста чтобы он стал standart

```bash
kubectl get pvc
NAME         STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
broken-pvc   Bound    pvc-c13004d9-f4fa-472c-a2cc-e3ec29657819   1Gi        RWO            standard       <unset>                 5s
kubectl get pods
NAME          READY   STATUS    RESTARTS   AGE
pending-pvc   1/1     Running   0          13m
```

3. Не сошёлся nodeSelector.

Написли манифест для пода и запустили его

```bash
kubectl apply -f manifests/selector_pod.yml
pod/pending-selector created

kubectl get pods
NAME               READY   STATUS    RESTARTS   AGE
pending-selector   0/1     Pending   0          18s
```

Под не запустился идем в describe

```bash
kubectl describe pod pending-selector
Name:             pending-selector
Namespace:        default
Priority:         0
Service Account:  default
Node:             <none>
Labels:           <none>
Annotations:      <none>
Status:           Pending
IP:
IPs:              <none>
Containers:
  app:
    Image:        nginx:alpine
    Port:         <none>
    Host Port:    <none>
    Environment:  <none>
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-dj4tm (ro)
Conditions:
  Type           Status
  PodScheduled   False
Volumes:
  kube-api-access-dj4tm:
    Type:                    Projected (a volume that contains injected data from multiple sources)
    TokenExpirationSeconds:  3607
    ConfigMapName:           kube-root-ca.crt
    Optional:                false
    DownwardAPI:             true
QoS Class:                   BestEffort
Node-Selectors:              hardware=quantum-computer
Tolerations:                 node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                             node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
Events:
  Type     Reason            Age   From               Message
  ----     ------            ----  ----               -------
  Warning  FailedScheduling  69s   default-scheduler  0/1 nodes are available: 1 node(s) didn't match Pod's node affinity/selector. no new claims to deallocate, preemption: 0/1 nodes are available: 1 Preemption is not helpful for scheduling.
```

Под находится в Pending, и нода: <none>, значит он ещё не был назначен на ноду. В describe видно Node-Selectors: hardware=quantum-computer. В Events scheduler сообщает didn't match Pod's node affinity/selector. Значит проблема в том, что ни одна нода не имеет требуемого label.


Добавим ноде нужный label

```bash
kubectl label node minikube hardware=quantum-computer
```

И пода заработала

```bash
NAME               READY   STATUS    RESTARTS   AGE
pending-selector   1/1     Running   0          3m53s
```