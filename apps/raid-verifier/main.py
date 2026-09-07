import json, logging, os, sqlite3, ssl, threading, time, urllib.request
from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from kafka import KafkaConsumer, TopicPartition
from proof import Proof, proof_ready
logging.basicConfig(level=logging.INFO)
logging.getLogger("kafka").setLevel(logging.WARNING)
os.makedirs('/data',exist_ok=True)
proof=Proof(os.getenv('DB_PATH','/data/proof.db'))
lock=threading.RLock()
status={'ready':False,'error':None,'consumerLag':None,'kafkaLag':None,'parallelism':None,'taskManagers':None,'timeline':[],'evidenceRevision':0}
latencies=deque(maxlen=10000); arrivals=deque(); active={}
cached=proof.report();cached_revision=-1;cached_at=0
TOPICS=['raid-attacks','raid-score-updates','raid-integrity']
def consume():
    try:
        c=KafkaConsumer(bootstrap_servers=os.getenv('BOOTSTRAP','raid-kafka-bootstrap.kafka:9092'),
            enable_auto_commit=False,isolation_level='read_committed',auto_offset_reset='earliest',
            value_deserializer=lambda b:json.loads(b),request_timeout_ms=40000)
        parts=[]
        for topic in TOPICS:
            p=c.partitions_for_topic(topic)
            if not p:raise RuntimeError('Topic unavailable: '+topic)
            parts.extend(TopicPartition(topic,i) for i in sorted(p))
        c.assign(parts)
        beginnings=c.beginning_offsets(parts)
        with lock:
            for tp in parts:
                row=proof.db.execute('SELECT pos FROM offsets WHERE topic=? AND part=?',(tp.topic,tp.partition)).fetchone()
                pos=row[0] if row else 0
                if beginnings[tp]>pos:raise RuntimeError('Kafka retention removed unverified history; reset the entire demo')
                c.seek(tp,pos)
        last=0
        while True:
            with lock:
                if status.pop('resetRequested',False):
                    if any(c.beginning_offsets(parts).values()):
                        raise RuntimeError('Cannot replay: Kafka retention removed history')
                    for table in ('events','offsets','counters'):
                        proof.db.execute('DELETE FROM '+table)
                    proof.db.commit()
                    for p in parts:c.seek(p,0)
                    latencies.clear();arrivals.clear();active.clear()
                    status.update(ready=False,consumerLag=None)
                    status['evidenceRevision']+=1
            batch=c.poll(timeout_ms=500,max_records=2000)
            with lock:
                for tp,records in batch.items():
                    for r in records:
                        proof.ingest(tp.topic,tp.partition,r.offset,r.value)
                        if tp.topic=='raid-score-updates':
                            now=time.time();latencies.append(max(0,now*1000-r.value['createdAtEpochMs']))
                            arrivals.append(now);active[r.value['playerId']]=now
                proof.db.commit()
                if batch:status['evidenceRevision']+=1
                status['ready']=True
            if time.time()-last>3:
                ends=c.end_offsets(parts)
                lag=sum(max(0,ends[p]-c.position(p)) for p in parts)
                # Transaction control records consume offsets too; persist consumer positions.
                with lock:
                    for p in parts:
                        proof.db.execute('INSERT INTO offsets VALUES (?,?,?) ON CONFLICT(topic,part) DO UPDATE SET pos=excluded.pos',(p.topic,p.partition,c.position(p)))
                    proof.db.commit();status['consumerLag']=lag;status['lagUpdatedAt']=time.time()
                last=time.time()
    except Exception as e:
        logging.exception('Verifier stopped')
        with lock:status.update(ready=False,error=str(e))
def fetch(url,headers=None,context=None):
    return json.load(urllib.request.urlopen(urllib.request.Request(url,headers=headers or {}),timeout=3,context=context))
def telemetry():
    previous=None
    while True:
        state={}
        try:
            root='http://raid-score-engine-rest.flink:8081'
            jobs=fetch(root+'/jobs/overview')['jobs']
            job=jobs[0] if jobs else {}
            details=fetch(root+'/jobs/'+job['jid']) if job else {}
            state.update(parallelism=max((v['parallelism'] for v in details.get('vertices',[])),default=0),flinkState=job.get('state','UNKNOWN'))
            token=open('/var/run/secrets/kubernetes.io/serviceaccount/token').read()
            ctx=ssl.create_default_context(cafile='/var/run/secrets/kubernetes.io/serviceaccount/ca.crt')
            pods=fetch('https://kubernetes.default.svc/api/v1/namespaces/flink/pods?labelSelector=app%3Draid-score-engine%2Ccomponent%3Dtaskmanager',{'Authorization':'Bearer '+token},ctx)['items']
            state['taskManagers']=sum(any(c.get('type')=='Ready' and c.get('status')=='True' for c in p.get('status',{}).get('conditions',[])) for p in pods)
            signature=(state['flinkState'],tuple(sorted(p['metadata']['uid'] for p in pods)))
            if signature!=previous:
                with lock:
                    status['timeline'].append(dict(time=time.strftime('%H:%M:%S'),message=f"Flink {state['flinkState']}; {state['taskManagers']} ready workers; pod set changed"))
                    status['timeline']=status['timeline'][-30:]
                previous=signature
            # Committed Flink source offsets are checkpoint based.
            c=KafkaConsumer(bootstrap_servers=os.getenv('BOOTSTRAP','raid-kafka-bootstrap.kafka:9092'),group_id='raid-score-engine',enable_auto_commit=False)
            ps=[TopicPartition('raid-attacks',p) for p in c.partitions_for_topic('raid-attacks')]
            ends=c.end_offsets(ps)
            state['kafkaLag']=sum(max(0,ends[p]-(c.committed(p) or 0)) for p in ps)
            c.close()
            state['telemetryError']=None
            state['telemetryUpdatedAt']=time.time()
        except Exception as e:
            state.update(telemetryError=str(e),kafkaLag=None,parallelism=None,taskManagers=None)
        with lock:status.update(state)
        time.sleep(5)
def snapshots():
    global cached,cached_revision,cached_at
    reader=object.__new__(Proof)
    reader.db=sqlite3.connect('file:'+os.getenv('DB_PATH','/data/proof.db')+'?mode=ro',uri=True)
    while True:
        try:
            # Establish a consistent WAL read snapshot while the writer is briefly locked.
            with lock:
                reader.db.execute('BEGIN')
                reader.db.execute('SELECT count(*) FROM offsets').fetchone()
                revision=status['evidenceRevision']
                started=time.time()
            report=reader.report()
            reader.db.commit()
            with lock:
                cached=report;cached_revision=revision;cached_at=started
                status['snapshotError']=None
        except Exception as e:
            reader.db.rollback()
            logging.exception('Snapshot calculation failed')
            with lock:status['snapshotError']=str(e)
        time.sleep(2)
class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        with lock:
            if self.path=='/health':data=dict(ready=status['ready'],error=status['error']);code=200 if status['ready'] else 503
            elif self.path=='/metrics-json':
                data=dict(cached);data.update(status);code=200
                data.update(snapshotAgeSeconds=round(time.time()-cached_at,1),snapshotRevision=cached_revision)
                now=time.time()
                while arrivals and arrivals[0]<now-10:arrivals.popleft()
                for p in list(active):
                    if active[p]<now-30:del active[p]
                samples=sorted(latencies)
                data.update(attacksPerSec=len(arrivals)/10,playersOnline=len(active),
                    latency={f'p{p}':round(samples[min(len(samples)-1,int(len(samples)*p/100))],1) if samples else None for p in (50,95,99)})
                data['proofPass']=proof_ready(data,status,cached_revision,time.time())
            else:data={'error':'not found'};code=404
        self.send_response(code);self.send_header('Content-Type','application/json');self.end_headers();self.wfile.write(json.dumps(data).encode())
    def do_POST(self):
        if self.path=='/reset':
            with lock:
                status.update(resetRequested=True,ready=False,consumerLag=None)
            self.send_response(202);data={'message':'Replaying all retained Kafka evidence from offset zero'}
        else:
            self.send_response(404);data={'error':'not found'}
        self.send_header('Content-Type','application/json');self.end_headers();self.wfile.write(json.dumps(data).encode())
threading.Thread(target=snapshots,daemon=True).start()
threading.Thread(target=consume,daemon=True).start()
threading.Thread(target=telemetry,daemon=True).start()
ThreadingHTTPServer(('0.0.0.0',8080),Handler).serve_forever()
