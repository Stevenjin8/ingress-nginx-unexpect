kind:
	~/istio/samples/kind-lb/setupkind.sh -n cluster1 -s 100

# Install infra components
install:
	helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace || true
	kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml
	istioctl install -y --set hub=gcr.io/istio-release --set tag=1.29.0
	kubectl apply -f ./httpbin.yaml

