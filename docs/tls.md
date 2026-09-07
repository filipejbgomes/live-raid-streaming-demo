# External HTTPS with cert-manager and Let's Encrypt

The external access path is browser → TLS ingress controller → internal dashboard → internal verifier. Only read-only dashboard metrics are proxied. Kafka, Flink, object storage and `/reset` have no public routes.

## Configure

Set `KUBE_CONTEXT`, `DASHBOARD_HOST`, `ACME_EMAIL` and the existing `INGRESS_CLASS`. Run `ACME_ENV=staging ./scripts/expose-dashboard.sh ingress` first. The hostname must be a real public DNS name, not `localhost` or an IP address. Its A/AAAA records must route to the ingress controller and both internet clients and cluster pods must be able to reach its HTTP-01 endpoint on port 80. Port 443 serves the application. Remove an incorrect AAAA record if IPv6 does not reach the controller.

When staging issuance succeeds, run `ACME_ENV=production ./scripts/expose-dashboard.sh ingress`. Staging certificates are deliberately untrusted. Staging and production use different Issuers and ACME account Secrets. The script waits for the Certificate's current generation to become Ready, so the old staging readiness cannot be mistaken for production issuance. Default `TLS_SECRET` is `raid-dashboard-tls`; default certificate wait is 600 seconds, configurable via `CERT_TIMEOUT`.

`loadbalancer` mode installs the pinned Traefik chart 35.0.0 in `observability`, using class `raid-traefik`. It requires a working LoadBalancer implementation. Existing-controller `ingress` mode avoids installing or changing a controller. Do not run HTTP-only direct LoadBalancer exposure for the application; the script keeps its Service internal and places TLS termination at the controller.

For a private-only cluster, Let's Encrypt HTTP-01 cannot reach the challenge. Use a preconfigured DNS-01 cert-manager issuer to manage a TLS Secret according to your DNS environment, then set `TLS_MODE=existing` and `TLS_SECRET`. The demo does not need or handle DNS provider credentials. Local development uses port-forwarding by default.

## Inspect and renew

```bash
kubectl -n demo get issuer,certificate,certificaterequest,order,challenge
kubectl -n demo describe certificate raid-dashboard
kubectl -n demo describe issuer raid-letsencrypt-production
kubectl -n cert-manager logs deployment/cert-manager --tail=100
kubectl -n demo get certificate raid-dashboard -o jsonpath='{.status.notAfter}{"\n"}{.status.renewalTime}{"\n"}'
curl -I https://raid.example.org
curl -I http://raid.example.org
```

Use `kubectl --context "$KUBE_CONTEXT"` when your desired context differs from the shell's current context. Certificates request renewal 15 days before expiry and rotate the private key on reissuance. cert-manager updates the Secret; the controller watches it and loads renewed certificates automatically. Application pods do not read private keys and do not need restart on certificate renewal.

An HTTP request should redirect to HTTPS. Cert-manager's separate solver Ingress answers `/.well-known/acme-challenge/…` directly. If a Certificate is Pending, inspect its Challenge: common causes are missing DNS, blocked port 80, wrong ingress class, or incorrect IPv6 routing. A ready Certificate does not by itself prove external reachability; test the HTTPS URL from a browser outside the cluster. Issuance uses the real ACME service and cannot be validated offline or for a fabricated example hostname.

Cleanup removes the demo Ingress and Certificate but retains shared cert-manager/Traefik installations, TLS Secret and ACME account Secrets. Local `cleanup.sh --cluster` deletes the whole dedicated cluster. Existing external clusters are never deleted by the scripts.

References: [cert-manager Helm installation](https://cert-manager.io/v1.17-docs/installation/helm/), [HTTP-01 validation](https://cert-manager.io/docs/configuration/acme/http01/), [certificate renewal](https://cert-manager.io/docs/usage/certificate/).
