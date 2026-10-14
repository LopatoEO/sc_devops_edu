# Этап 0. Кластер и инструменты

## Задача

Подними локальный кластер на `kind` или `minikube`. Поставь `kubectl`, настрой автодополнение и контекст.

**Приёмка:**

- `kubectl get nodes` показывает ноды в статусе Ready
- объяснить разницу между нодой, подом и контейнером
- запустить одноразовый под `kubectl run tmp --image=alpine -it --rm -- sh`, осмотреться, выйти

## Выполнение

Для работы решил использовать Minikube, так как работаю на мак установил minikube и kubectl через brew коммандами

```shell
brew install minikube
brew install kubectl
```

Запустил кластер коммандой

```shell
minikube start
--nodes=2
--cpus=2
--memory=1536
```

Проверил контекст

```shell
kubectl config get-contexts
```

По выводу убедился что контекст выбран правильно

```text
CURRENT   NAME       CLUSTER    AUTHINFO   NAMESPACE
*         minikube   minikube   minikube   default
```

Получил ноды при помощи комманды

```bash
kubectl get nodes
```

Вывод:

```text
NAME           STATUS   ROLES           AGE   VERSION
minikube       Ready    control-plane   55s   v1.35.1
minikube-m02   Ready    <none>          31s   v1.35.1
```

Разница между нодом подом и контейнером:

- Нода это машина на которой запускаются поды, может быть как и физической машиной так и виртуалкой. В моём случае Minikube использует Docker driver, поэтому ноды представлены Docker-контейнерами.моем случае нодой выступает докер контейнер
- Под это минимальная запускаемая сущность кубера, размещается на ноде и запускает один или несколько контейнеров
- Контейнер это конкретный запущенный образ приложения

Запустил одноразовый под коммандой

```bash
kubectl run tmp --image=alpine -it --rm -- sh
```

Запустил в нем несколько стандартных linux коммманд

```bash
/ # ls
bin    etc    lib    mnt    proc   run    srv    tmp    var
dev    home   media  opt    root   sbin   sys    usr
/ # pwd
/
/ # nano
sh: nano: not found
/ # touch test
/ # ls
bin    etc    lib    mnt    proc   run    srv    test   usr
dev    home   media  opt    root   sbin   sys    tmp    var
/ #
```
