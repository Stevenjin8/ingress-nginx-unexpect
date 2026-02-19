# Before you Migrate: 7 Unexpected Ingress NGINX Behaviors that you need to Know Before you Migrate

As announced in many other places, Kubernetes will retire Ingress NGINX in March 2026[^1].
Ingress NGINX is full of surprising defaults and side effects that you might be relying on.
This blog highlights these behaviors so that you can make a conscious decision about what to keep, and migrate away safely.
We will also compare this behavior with Gateway API and offer ways to preserve this behavior.

We assume that the reader has some familiarity for Ingress NGINX and the Ingress API
For all examples, we will use [`httpbin`](https://github.com/postmanlabs/httpbin) as the backend.
All code for this blog can be found at [xyz](TODO)

## Regex Matching is Prefix and Case Insenitive

Consider the following Ingress:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: regex-match-ingress
  annotations:
    nginx.ingress.kubernetes.io/use-regex: "true"
spec:
  ingressClassName: nginx
  rules:
  - host: regex-match.example.com
    http:
      paths:
      - path: "/u[A-Z]"
        pathType: ImplementationSpecific
        backend:
          service:
            name: httpbin
            port:
              number: 8000
```

We would expect that this Ingress would only match requests with a path of exactly a `u` followed by one one uppercase letter.
But the following request shows that this is not the case.

```bash
$ curl -iS -HHost:regex-match.example.com 172.19.100.200/uuid
HTTP/1.1 200 OK
Date: Thu, 19 Feb 2026 16:55:31 GMT
Content-Type: application/json; charset=utf-8
Content-Length: 53
Connection: keep-alive
Access-Control-Allow-Credentials: true
Access-Control-Allow-Origin: *

{
  "uuid": "e55ef929-25a0-49e9-9175-1b6e87f40af7"
}
```

> The /uuid endpoint of httpbin simply returns a random uuid, so the fact that we get a 200 response with a uuid in the body means that our request was successfully routed to httpbin.

Because Ingress NGINX does prefix and case insensitive matching, this Ingress will match any path that starts with a `u` and any letter, such as `/uuid`.
As such, Ingress NGINX forwards `/uuid` to `httpbin`, rather than responding with a 404 Not Found.
In other words, `path: "/u[A-Z]"` is equivalent to `path: "/u[a-zA-Z].*"`.

With Gateway API, you can use [`HTTPPathMatch`](https://gateway-api.sigs.k8s.io/reference/spec/#httppathmatch) a `type` of `RegularExpression` to achieve the same behavior as Ingress NGINX, or a `type` of `RegularExpression` to do regular expression matching,
but this matching will be case sensitive and will not do prefix matching by default.
You can make make your pattern a prefix match by adding `.*` to the end of your regex pattern.
If you Gateway API implementation supports RE2 regex flags (most Envoy-based implementations), you can use the `(?i)` flag to make your regex pattern case insensitive.

## Regex Applies to all Paths of a Host Across All Ingresses.

Consider the following Ingress in addition to the previous one:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: regex-match-ingress-other
spec:
  ingressClassName: nginx
  rules:
  - host: regex-match.example.com
    http:
      paths:
      - path: "/HEAD"
        pathType: Exact
        backend:
          service:
            name: httpbin
            port:
              number: 8000
```

Naively, we would a request to `/headers` to respond with a 404 Not Found, since `/headers` does not match the `Exact` path of `/HEAD`.
But because the `regex-match-ingress` Ingress has the `nginx.ingress.kubernetes.io/use-regex: "true"` annotation and the `regex-match.example.com` host, Ingress NGINX treats `/HEAD` as a regex pattern.
In other words, the `pathType` is ignored, because of an annotation defined in a different Ingress that shares the same host.
Since regex patterns are case-insensitive and prefix matches, `/headers` matches the regex pattern of `/HEAD` and is forwarded to `httpbin`, rather than responding with a 404 Not Found as seen below.

```bash
$ curl -iS -HHost:regex-match.example.com 172.19.100.200/headers

HTTP/1.1 200 OK
Date: Thu, 19 Feb 2026 17:13:33 GMT
Content-Type: application/json; charset=utf-8
Content-Length: 565
Connection: keep-alive
Access-Control-Allow-Credentials: true
Access-Control-Allow-Origin: *

{
  "headers": {
    ...
  }
}
```

Gateway API does not silently convert your `Exact` or `Prefix` matches into regex patterns.

## Rewrite Target implies Regex

Consider the following Ingresses:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rewrite-target-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: "/uuid"
spec:
  ingressClassName: nginx
  rules:
  - host: rewrite-target.example.com
    http:
      paths:
      - path: "/[abc]"
        pathType: ImplementationSpecific
        backend:
          service:
            name: httpbin
            port:
              number: 8000
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rewrite-target-ingress-other
spec:
  ingressClassName: nginx
  rules:
  - host: rewrite-target.example.com
    http:
      paths:
      - path: "/HEAD"
        pathType: Exact
        backend:
          service:
            name: httpbin
            port:
              number: 8000
```

Even thought we never use the `nginx.ingress.kubernetes.io/use-regex: "true"` annotation,
the presence of the `nginx.ingress.kubernetes.io/rewrite-target` annotation in the `rewrite-target-ingress` Ingress causes all paths with the `rewrite-target.example.com` host to be treated as regex patterns.

For example, a request to `/ABCdef` responds with a redirect because `/ABCdef` matches the case insensitive regex pattern of `/[abc]+`:

```bash
$ curl -iS -HHost:rewrite-target.example.com 172.19.100.200/ABCdef
HTTP/1.1 308 Permanent Redirect
Date: Thu, 19 Feb 2026 17:28:44 GMT
Location: /uuid
Content-Length: 0
Connection: keep-alive
```

And, as before, the `path`s of other ingresses with the `rewrite-target.example.com` host are also treated as regex patterns.

```bash
$ curl -iS -HHost:regex-match.example.com 172.19.100.200/headers

HTTP/1.1 200 OK
Date: Thu, 19 Feb 2026 17:13:33 GMT
Content-Type: application/json; charset=utf-8
Content-Length: 565
Connection: keep-alive
Access-Control-Allow-Credentials: true
Access-Control-Allow-Origin: *

{
  "headers": {
    ...
  }
}
```

You can configure path rewrites with Gateway API with the [`HTTPURLRewriteFilter`](https://gateway-api.sigs.k8s.io/reference/spec/#httpurlrewritefilter)
which will not silently convert your `Exact` and `Prefix` matches into regex patterns.

## Request Missing a Trailing Slash is Redirected to the Same Path with a Trailing Slash

Consider the following Ingress:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: trailing-slash-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: trailing-slash.example.com
    http:
      paths:
      - path: "/header/"
        pathType: Exact
        backend:
          service:
            name: httpbin
            port:
              number: 8000
```

Naively, we would expect Ingress NGINX to respond to `/headers` with a 404 Not Found since the path of `/headers` does not exactly match the `Exact` path of `/headers/`.
However, Ingress NGINX redirects the request to `/headers/` with a 301 Moved Permanently instead because the difference between `/headers` and `/headers/` is just a trailing slash.

```bash
$ curl -iS -HHost:trailing-slash.example.com 172.19.100.200/header
HTTP/1.1 301 Moved Permanently
Date: Thu, 19 Feb 2026 17:44:55 GMT
Location: /header/
Content-Length: 0
Connection: keep-alive
```

The same applies if we change the `pathType` to `Prefix`.
However, the redirect will not happen if the path is a regex pattern.

Gateway API will not silently redirect requests that are missing a trailing slash to the same path with a trailing slash.
You can explicitly configure redirects using the [`HTTPRequestRedirectFilter`](https://gateway-api.sigs.k8s.io/reference/spec/#httprequestredirectfilter).

## Path Normalization is Enabled by Default

Path normalization is the process of converting a URL path into a canonical format before matching it against Ingress rules and forwarding it to the backend.
Ingress NGINX enables path normalization by default, which will take paths like `/foo//bar/../baz` and normalize it to `/foo/baz` before matching it against Ingress rules.
For example, consider the following Ingress:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: path-normalization-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: path-normalization.example.com
    http:
      paths:
      - path: "/ip"
        pathType: Exact
        backend:
          service:
            name: httpbin
            port:
              number: 8000
```

Sending request to the following paths will all be normalized to `/ip` and match the `Exact` path of `/ip`, resulting in a 200 OK response or a 301 Moved Permanently to `/ip`.

```bash
$ curl -S -HHost:path-normalization.example.com 172.19.100.200/ip
{
    "origin": "10.0.0.4"
}

$ curl -S -HHost:path-normalization.example.com 172.19.100.200/ip/abc/../../ip
{
  "origin": "10.244.0.1"
}

$ curl -Si -HHost:path-normalization.example.com 172.19.100.200////ip
HTTP/1.1 301 Moved Permanently
Date: Thu, 19 Feb 2026 18:01:38 GMT
Content-Type: text/html; charset=utf-8
Content-Length: 38
Connection: keep-alive
Access-Control-Allow-Credentials: true
Access-Control-Allow-Origin: *
Location: /ip

<a href="/ip">Moved Permanently</a>.
```

Your backends might rely on the Ingress/Gateway API implementation path do normaliza paths.
Gateway API does not have a way to configure path normalization.
Check implementation-specific documentation for your Gateway API implementation for more specifics.

[^1]: https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/
