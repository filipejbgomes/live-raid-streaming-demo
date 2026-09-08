import json, os, ssl, threading, time, urllib.request
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

API='https://kubernetes.default.svc';TOKEN='/var/run/secrets/kubernetes.io/serviceaccount/token'
control={'state':'READY','message':'Boss raid ready — waiting for presenter','actions':[]};lock=threading.Lock()
def record(state,message):
    with lock:
        control['state']=state;control['message']=message
        control['actions']=(control['actions']+[{'time':time.strftime('%H:%M:%S'),'message':message}])[-12:]
def request_json(url,method='GET',body=None):
    data=json.dumps(body).encode() if body is not None else None
    headers={'Authorization':'Bearer '+open(TOKEN).read(),'Accept':'application/json'}
    if data:headers['Content-Type']='application/merge-patch+json'
    ctx=ssl.create_default_context(cafile='/var/run/secrets/kubernetes.io/serviceaccount/ca.crt') if url.startswith(API) else None
    with urllib.request.urlopen(urllib.request.Request(url,method=method,data=data,headers=headers),timeout=12,context=ctx) as response:
        return json.load(response) if response.length!=0 else {}
def kube(path,method='GET',body=None):return request_json(API+path,method,body)
def scale(replicas,message):
    kube('/apis/apps/v1/namespaces/demo/deployments/bossraid-player-generator','PATCH',{'spec':{'replicas':replicas}})
    record('LIVE' if replicas else 'STOPPED',message)
def upgrade():
    try:
        record('UPGRADING','Saving Bossraid state before rules upgrade…')
        path='/apis/flink.apache.org/v1beta1/namespaces/flink/flinkdeployments/bossraid-score-engine'
        kube(path,'PATCH',{'spec':{'job':{'state':'suspended','upgradeMode':'savepoint'}}})
        deadline=time.time()+600
        while time.time()<deadline:
            job=kube(path).get('status',{}).get('jobStatus',{})
            if job.get('state')=='FINISHED' and job.get('upgradeSavepointPath'):
                kube(path,'PATCH',{'spec':{'image':'bossraid-score-engine-v2:local','job':{'state':'running','upgradeMode':'savepoint'}}})
                record('UPGRADED','Scoring rules upgraded to v2 from a savepoint');return
            time.sleep(3)
        raise RuntimeError('Timed out waiting for the savepoint')
    except Exception as error:record('ACTION FAILED',f'Upgrade failed: {error}')
def control_action(action):
    if action=='start':scale(2,'Boss raid started with two player groups')
    elif action=='scale':scale(8,'Player load increased to eight groups')
    elif action=='stop':scale(0,'Player generation stopped; processing can drain')
    elif action=='kill-worker':
        pods=kube('/api/v1/namespaces/flink/pods?labelSelector=app%3Dbossraid-score-engine%2Ccomponent%3Dtaskmanager')['items']
        if not pods:raise RuntimeError('No processing worker is available to restart')
        name=pods[0]['metadata']['name'];kube('/api/v1/namespaces/flink/pods/'+name,'DELETE')
        record('RECOVERING',f'Processing worker {name} removed; Kubernetes is replacing it')
    elif action=='upgrade':threading.Thread(target=upgrade,daemon=True).start()
    elif action=='verify':
        metrics=request_json('http://bossraid-verifier:8080/metrics-json')
        record('VERIFIED' if metrics.get('proofPass') else 'CHECKING','Every attack is accounted for' if metrics.get('proofPass') else 'Still waiting for processing to drain')
    else:raise RuntimeError('Unknown action')
class Handler(SimpleHTTPRequestHandler):
    def do_GET(self):
        host=os.getenv('DASHBOARD_HOST')
        if host and self.headers.get('X-Forwarded-Proto','').split(',')[0].strip()=='http':
            self.send_response(308);self.send_header('Location','https://'+host+self.path);self.end_headers();return
        try:
            if self.path=='/metrics-json':data=request_json('http://bossraid-verifier:8080/metrics-json')
            elif self.path=='/control-status':
                with lock:data=dict(control)
            else:return super().do_GET()
            self.send_response(200);self.send_header('Content-Type','application/json');self.end_headers();self.wfile.write(json.dumps(data).encode())
        except Exception as error:self.send_error(503,str(error))
    def do_POST(self):
        if not self.path.startswith('/control/'):self.send_error(404,'not found');return
        try:
            control_action(self.path.rsplit('/',1)[1])
            with lock:data=dict(control)
            self.send_response(202);self.send_header('Content-Type','application/json');self.end_headers();self.wfile.write(json.dumps(data).encode())
        except Exception as error:self.send_error(409,str(error))
ThreadingHTTPServer(('0.0.0.0',8080),Handler).serve_forever()
