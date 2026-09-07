import json, os, pathlib, re, sys
root=pathlib.Path(__file__).resolve().parents[1]
host=os.environ.get('DASHBOARD_HOST','')
if not re.fullmatch(r'(?=.{1,253}$)(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63}',host):
    sys.exit('DASHBOARD_HOST must be a DNS hostname, without scheme or path')
klass=os.environ.get('INGRESS_CLASS','')
if not klass:sys.exit('INGRESS_CLASS is required')
env=os.environ.get('ACME_ENV','production')
if env not in ('staging','production'):sys.exit('ACME_ENV must be staging or production')
email=os.environ.get('ACME_EMAIL','')
if sys.argv[1]=='tls' and '@' not in email:sys.exit('ACME_EMAIL is required for Let\'s Encrypt registration')
issuer='raid-letsencrypt-'+env
values={'__HOST__':host,'__INGRESS_CLASS__':klass,'__EMAIL__':email,'__ISSUER__':issuer,
    '__ACCOUNT_SECRET__':issuer+'-account','__TLS_SECRET__':os.environ.get('TLS_SECRET','raid-dashboard-tls'),
    '__ACME_SERVER__':'https://acme-'+('staging-' if env=='staging' else '')+'v02.api.letsencrypt.org/directory'}
source=(root/'k8s/observability'/('tls.yaml' if sys.argv[1]=='tls' else 'ingress.yaml')).read_text()
for token,value in values.items():source=source.replace(token,json.dumps(value))
print(source)
