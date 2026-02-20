---
layout: blog
title: "Before You Migrate: 5 Unexpected Ingress NGINX Behaviors You Need to Know (You won't believe the first one)"
date: 2026-02-20
draft: true
author: >
  [Steven Jin](https://github.com/Stevenjin8) (Microsoft)
---

[As announced November 2025](/blog/2025/11/11/ingress-nginx-retirement/), Kubernetes will retire Ingress NGINX in March 2026.
Despite its widespread usage, Ingress NGINX is full of surprising defaults and side effects that are probably present in your cluster today.
This blog highlights these behaviors so that you can migrate away safely and make a conscious decision about which behaviors to keep.
This post will also compare Ingress NGINX with Gateway API and offer ways to preserve Ingress NGINX behavior in Gateway API.

I'm going to assume that you, the reader, have some familiarity with Ingress NGINX and the Ingress API.
For most examples, we will use [`httpbin`](https://github.com/postmanlabs/httpbin) as the backend.

## 1. Ingress NGINX and NGINX Ingress are different projects

Although you might have to squint to see the difference, [Ingress NGINX](https://github.com/kubernetes/ingress-nginx) is an Ingress controller maintained and governed by the Kubernetes community that is retiring March 2026.
[NGINX Ingress](https://docs.nginx.com/nginx-ingress-controller/) is an Ingress controller by F5.
Although both use NGINX as the dataplane they are different.
They
* are not different versions of the same controller.
* are not they forks of each other.
* do not share the same api (other than the Ingress API).

## 2. Regex matching is prefix and case insensitive

Consider the following Ingress:

```yaml=
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

Due to the `/u[A-Z]` pattern, one would expect that this Ingress would only match requests with a path of only a `u` followed by one uppercase letter, but this is not the case.

```bash
$ curl -sS -HHost:regex-match.example.com 172.19.100.200/uuid
{
  "uuid": "e55ef929-25a0-49e9-9175-1b6e87f40af7"
}
```

{{< note >}}
The `/uuid` endpoint of httpbin simply returns a random uuid. A uuid in the body means that the request was successfully routed to httpbin.
{{< /note >}}

Because Ingress NGINX does [prefix case-insensitive](https://kubernetes.github.io/ingress-nginx/user-guide/ingress-path-matching/) matching, the `/u[A-Z]` pattern will match **any** path that starts with a `u` or `U` followed by any letter, such as `/uuid`.
As such, Ingress NGINX forwards `/uuid` to `httpbin`, rather than responding with a 404 Not Found.
In other words, `path: "/u[A-Z]"` is equivalent to `path: "/[uU][a-zA-Z].*"`.

With Gateway API, you can use [HTTP path match](https://gateway-api.sigs.k8s.io/reference/spec/#httppathmatch) with a `type` of `RegularExpression` for regular expression path matching.
`RegularExpression` matches are implementation specific in Gateway API, so check with your Gateway API implementation to verify the semantics of `RegularExpression` matching.

That said, popular Envoy-based Gateway API implementations such as Istio, Envoy Gateway, and Kgateway use  RE2 for their regex flavor and do a full, case-sensitive match.

Thus, an equivalent HTTP route would look as follows

```yaml=
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: regex-match-route
spec:
  hostnames:
  - regex-match.example.com
  parentRefs:
  - name: my-gateway  # Change this depending on your use case
  rules:
  - matches:
    - path:
        type: RegularExpression
        value: "/[uU][a-zA-Z].*"
    backendRefs:
    - name: httpbin
      port: 8000
```

`[uU][a-zA-Z]` matches a `u` or `U` and then any letter, and `.*` matches any number of any character.
Alternatively, proxies that use RE2 for their regex engine can also use the `(?i)` flag to indicate case insentive matches, and the pattern could also be `(?i)/u[A-Z].*` instead of `/[uU][a-zA-Z].*`.

## 3. The `nginx.ingress.kubernetes.io/use-regex` applies to all paths of a host across all (Ingress NGINX) Ingresses

Consider the following Ingresses:

```yaml=
---
# This ingress is the same as above
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
---
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

Naively, one would expect a request to `/headers` to respond with a 404 Not Found, since `/headers` does not match the `Exact` path of `/HEAD`.
But because the `regex-match-ingress` Ingress has the `nginx.ingress.kubernetes.io/use-regex: "true"` annotation and the `regex-match.example.com` host, **all paths with the `regex-match.example.com` host are treated as regular expressions across all (Ingress NGINX) Ingresses.** 
Since regex patterns are case-insensitive and prefix matches, `/headers` matches the regex pattern of `/HEAD` and Ingress NGINX forwards the request to `httpbin`.

```bash
$ curl -sS -HHost:regex-match.example.com 172.19.100.200/headers
{
  "headers": {
    ...
  }
}
```


{{< note >}}
The `/headers` endpoint of httpbin simply returns the request headers. The fact that we get a response with the request headers in the body means that our request was successfully routed to httpbin.
{{< /note >}}

Gateway API does not silently convert nor interpret `Exact` and `Prefix` matches into regex patterns.
The following HTTP route would response with a 404 Not Found to a `/headers` request.

```yaml=
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: regex-match-route
spec:
  hostnames:
  - regex-match.example.com
  rules:
  - matches:
    - path:
        type: RegularExpression
        value: "/u[A-Z]" # or "/[uU][A-Za-z].*"
    backendRefs:
    - name: httpbin
      port: 8000
  - matches:
    - path:
        type: Exact
        value: "/HEAD"
    backendRefs:
    - name: httpbin
      port: 8000
```

If you wanted to keep the case-insenstive prefix matching, you can change

```yaml=16
  - matches:
    - path:
        type: Exact
        value: "/HEAD"
```

to

```yaml=16
  - matches:
    - path:
        type: RegularExpression
        value: "/[hH][eE][aA][dD].*"
```

## 4. Rewrite target implies regex

Consider the following Ingresses.:

```yaml=
---
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

The `nginx.ingress.kubernetes.io/rewrite-target: "/uuid"` annotation
causes requests that match paths in the `rewrite-target-ingress` Ingress to have their paths rewritten to `/uuid` before being forwarded to the backend.

Even though we never use the `nginx.ingress.kubernetes.io/use-regex: "true"` annotation,
the presence of the `nginx.ingress.kubernetes.io/rewrite-target` annotation in the `rewrite-target-ingress` Ingress causes **all paths with the `rewrite-target.example.com` host to be treated as regex patterns.**
In other words, the `nginx.ingress.kubernetes.io/rewrite-target` silently adds the `nginx.ingress.kubernetes.io/use-regex: "true"` annotation, along with all the side effects discussed above.

For example, a request to `/ABCdef` has its path rewritten to `/uuid` because `/ABCdef` matches the case-insensitive prefix pattern of `/[abc]` in the `rewrite-target-ingress` Ingress:

```bash
$ curl -sS -HHost:rewrite-target.example.com 172.19.100.200/ABCdef
{
  "uuid": "12a0def9-1adg-2943-adcd-1234gadfgc67"
}
```

Like in the `nginx.ingress.kubernetes.io/use-regex` example, Ingress NGINX treat `path`s of other ingresses with the `rewrite-target.example.com` host as case-insensitive prefix patterns.

```bash
$ curl -sS -HHost:regex-match.example.com 172.19.100.200/headers
{
  "headers": {
    ...
  }
}
```

You can configure path rewrites in Gateway API with the [HTTP URL rewrite filter](https://gateway-api.sigs.k8s.io/reference/spec/#httpurlrewritefilter),
which will not silently convert your `Exact` and `Prefix` matches into regex patterns.

```yaml=
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: rewrite-target-route
spec:
  hostnames:
  - regex-match.example.com
  parentRefs:
  - name: <your-gateway>
  rules:
  - matches:
    - path:
        type: RegularExpression
        value: "[abcABC].*" # or "[abc]" if you want exact case-sensitive matching
    filters:
    - type: URLRewrite
      urlRewrite:
        path:
          type: ReplaceFullPath
          replaceFullPath: /uuid
    backendRefs:
    - name: httpbin
      port: 8000
  - matches:
    - path:
        # This will be an exact match, irrespective of other rules
        type: Exact
        value: "/HEAD"
    backendRefs:
    - name: httpbin
      port: 8000
```

Again, the regex flavor is implementation specific, and you can keep the case-insensitive prefix match by changing

```yaml=16
  - matches:
    - path:
        type: Exact
        value: "/HEAD"
```

to

```yaml=16
  - matches:
    - path:
        type: RegularExpression
        value: "/[hH][eE][aA][dD].*"
```

## 5. Requests missing a trailing slash are redirected to the same path with a trailing slash

Consider the following Ingress:

```yaml=
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
      - path: "/mypath/"
        pathType: Exact
        backend:
          service:
            name: <your-backend>
            port:
              number: 8000
```

You might expect Ingress NGINX to respond to `/my-path` with a 404 Not Found since the `/my-path` does not exactly match the `Exact` path of `/my-path/`.
However, Ingress NGINX redirects the request to `/my-path/` with a 301 Moved Permanently because the only difference between `/my-path` and `/my-path/` is a trailing slash.

```bash
$ curl -isS -HHost:trailing-slash.example.com 172.19.100.200/my-path
HTTP/1.1 301 Moved Permanently
...
Location: http://trailing-slash.example.com/my-path/
...
```

The same applies if you change the `pathType` to `Prefix`.
However, the redirect will not happen if the path is a regex pattern.

Gateway API implementations will not silently redirect requests that are missing a trailing slash to the same path with a trailing slash.
You can explicitly configure redirects using the [HTTP request redirect filter](https://gateway-api.sigs.k8s.io/reference/spec/#httprequestredirectfilter) as follows

```yaml=
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: rewrite-target-route
spec:
  hostnames:
  - trailing-slash.example.com
  parentRefs:
  - name: <your-gateway>
  rules:
  - matches:
    - path:
        type: Exact
        value: "/my-path"
    filters:
      requestRedirect:
        statusCode: 301
        path:
          type: ReplaceFullPath
          replaceFullPath: /my-path/
  - matches:
    - path:
        type: Exact  # or Prefix
        value: "/my-path/"
    backendRefs:
    - name: <your-backend>
      port: 8000
```

## 5. Ingress NGINX Normalizes URLs

*Path normalization* is the process of converting a URL into a canonical form before matching it against Ingress rules and forwarding it to a backend.
The specifics of URL normalization are defined in [RFC 3986 Section 6.2](https://datatracker.ietf.org/doc/html/rfc3986#section-6.2), but some examples are

* deduplicatin consecutive slashes in a path: `my//path -> my/path`
* removing path segments that are just a `.`: `my/./path -> my/path`
* having a `..` path segment remove a previous segment: `my/../path -> /path`

Ingress NGINX normalizes URLs before matching them against Ingress rules.
For example, consider the following Ingress:

```yaml=
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
      - path: "/uuid"
        pathType: Exact
        backend:
          service:
            name: httpbin
            port:
              number: 8000
```

The following requests will  have their paths normalized to `/uuid` and match the `Exact` path of `/uuid`, resulting in a 200 OK response or a 301 Moved Permanently to `/uuid`.

```bash
$ curl -sS -HHost:path-normalization.example.com 172.19.100.200/uuid
{
  "uuid": "29c77dfe-73ec-4449-b70a-ef328ea9dbce"
}

$ curl -sS -HHost:path-normalization.example.com 172.19.100.200/ip/abc/../../uuid
{
  "uuid": "d20d92e8-af57-4014-80ba-cf21c0c4ffae"
}

$ curl -sSi -HHost:path-normalization.example.com 172.19.100.200////uuid
HTTP/1.1 301 Moved Permanently
...
Location: /uuid
...
```

Your backends might rely on the Ingress/Gateway API implementation to normalize URLs.
Gateway API does not have a way to configure path normalization.
Check implementation-specific documentation of your Gateway API implementation.

## Conclusion

As we all race to respond to the Ingress NGINX retirement, I hope this blog post instills some confidence that you can migrate safely and effectively despite all the intricacies of Ingress NGINX.

SIG Network has also been working on supporting the most common Ingress NGINX annotations (and some of these weird behaviors) in [Ingress2Gateway](https://github.com/kubernetes-sigs/ingress2gateway) to help you translate Ingress NGINX contiguration into Gateway API, and offer alternatives to unsupported behavior.
We are targeting a 1.0 release with these features late March 2026.

SIG Network is also about to release [Gateway API 1.5](https://github.com/kubernetes-sigs/gateway-api/releases/tag/v1.5.0-rc.1), which graduates features such as Listener sets that allows app developers to manage TLS certificates and the CORS filter that allows CORS configuration.
