## Этап 7. Ingress

Поставь ingress-controller на nginx. Заведи `Ingress`, чтобы `api` открывался по хосту `api.local` на пути `/api`. Пропиши хост в `/etc/hosts`.

**Приёмка:**

- `http://api.local/api` открывается без port-forward
- объяснить разницу между Service типа LoadBalancer и Ingress и зачем нужен роутинг по host и path

## Выполнение

Добавил манифест для ингресса и развернул приложение

Для начала надо включить аддон в миникубе и открыть тунель


```bash
minikube addons enable ingress
minikube tunnel
```

Затем в другом терминале выполним

```bash
curl -v http://api.local/api
* Host api.local:80 was resolved.
* IPv6: (none)
* IPv4: 127.0.0.1
*   Trying 127.0.0.1:80...
* Connected to api.local (127.0.0.1) port 80
> GET /api HTTP/1.1
> Host: api.local
> User-Agent: curl/8.7.1
> Accept: */*
> 
* Request completely sent off
< HTTP/1.1 200 OK
< Date: Sat, 19 Sep 2026 17:52:56 GMT
< Content-Type: application/json
< Content-Length: 31
< Connection: keep-alive
< 
* Connection #0 to host api.local left intact
{"service":"api","status":"ok"}%           
```



Service типа LoadBalancer публикует конкретный Service наружу через внешний балансировщик. Обычно он предоставляет внешнюю точку входа для одного Service.
Ingress работает на HTTP/HTTPS-уровне и позволяет одному ingress-controller принимать внешний трафик и маршрутизировать его в разные Kubernetes Service по имени хоста и пути запроса.
Например, маршрутизация по host позволяет направить:
api.example.com → api Service
admin.example.com → admin Service
А маршрутизация по path позволяет на одном домене направить:
/api → api Service
/auth → auth Service
/ → frontend Service
Поэтому Ingress позволяет использовать одну внешнюю точку входа для нескольких приложений вместо отдельного LoadBalancer для каждого Service.