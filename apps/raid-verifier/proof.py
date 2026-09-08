import hashlib, json, sqlite3
FIELDS = ('eventId','playerId','sequence','damage','createdAtEpochMs','generatorId')
def fingerprint(e):
    return hashlib.sha256(json.dumps({k:e[k] for k in FIELDS},sort_keys=True,separators=(',',':')).encode()).hexdigest()
class Proof:
    def __init__(self,path):
        self.db=sqlite3.connect(path,check_same_thread=False)
        self.db.executescript('''
        PRAGMA journal_mode=WAL;
        CREATE TABLE IF NOT EXISTS events(topic TEXT,id TEXT,player TEXT,seq INTEGER,hash TEXT,damage INTEGER,applied INTEGER,valid INTEGER,version TEXT,payload TEXT,PRIMARY KEY(topic,id));
        CREATE INDEX IF NOT EXISTS player_sequences ON events(topic,player,seq);
        CREATE INDEX IF NOT EXISTS global_order ON events(topic,json_extract(payload,'$.totalAttacks'));
        CREATE TABLE IF NOT EXISTS offsets(topic TEXT,part INTEGER,pos INTEGER,PRIMARY KEY(topic,part));
        CREATE TABLE IF NOT EXISTS counters(name TEXT PRIMARY KEY,value INTEGER);
        ''')
    def ingest(self,topic,part,offset,e):
        old=self.db.execute('SELECT pos FROM offsets WHERE topic=? AND part=?',(topic,part)).fetchone()
        if old and offset<old[0]:return
        try:
            self.db.execute('INSERT INTO events VALUES (?,?,?,?,?,?,?,?,?,?)',
                (topic,e['eventId'],e['playerId'],e['sequence'],fingerprint(e),e['damage'],
                 e.get('appliedDamage',0),int(e.get('valid',True)),e.get('version',''),json.dumps(e)))
        except sqlite3.IntegrityError:
            self.db.execute('INSERT INTO counters VALUES (?,1) ON CONFLICT(name) DO UPDATE SET value=value+1',('duplicates-'+topic,))
        self.db.execute('INSERT INTO offsets VALUES (?,?,?) ON CONFLICT(topic,part) DO UPDATE SET pos=excluded.pos',(topic,part,offset+1))
    def report(self):
        q=lambda sql,args=():self.db.execute(sql,args).fetchone()[0]
        expected=q("SELECT count(*) FROM events WHERE topic='bossraid-attacks'")
        output=q("SELECT count(*) FROM events WHERE topic='bossraid-score-updates'")
        integrity=q("SELECT count(*) FROM events WHERE topic='bossraid-integrity'")
        duplicates=q('SELECT coalesce(sum(value),0) FROM counters')
        missing=q("SELECT count(*) FROM events a LEFT JOIN events b ON a.id=b.id AND b.topic='bossraid-score-updates' WHERE a.topic='bossraid-attacks' AND b.id IS NULL")
        extra=q("SELECT count(*) FROM events b LEFT JOIN events a ON a.id=b.id AND a.topic='bossraid-attacks' WHERE b.topic='bossraid-score-updates' AND a.id IS NULL")
        gaps=q("SELECT coalesce(sum(mx-n),0) FROM (SELECT max(seq) mx,count(DISTINCT seq) n FROM events WHERE topic='bossraid-attacks' GROUP BY player)")
        mismatches=q('''SELECT count(*) FROM events a JOIN events b ON a.id=b.id AND b.topic='bossraid-score-updates'
            WHERE a.topic='bossraid-attacks' AND (a.hash!=b.hash OR b.version NOT IN ('v1','v2') OR b.applied!=a.damage*CASE WHEN b.version='v2' AND a.seq%10=0 THEN 2 ELSE 1 END)''')
        integrity_errors=q('''SELECT count(*) FROM events a LEFT JOIN events b ON a.id=b.id AND b.topic='bossraid-integrity'
            WHERE a.topic='bossraid-score-updates' AND (b.id IS NULL OR a.payload!=b.payload)''')
        invalid=q("SELECT count(*) FROM events WHERE topic='bossraid-score-updates' AND valid=0")
        damage=q("SELECT coalesce(sum(applied),0) FROM events WHERE topic='bossraid-score-updates'")
        rows=self.db.execute("SELECT payload FROM events WHERE topic='bossraid-score-updates' ORDER BY json_extract(payload, '$.totalAttacks') DESC LIMIT 1").fetchall()
        latest=max((json.loads(r[0]) for r in rows),key=lambda e:e['totalAttacks'],default={})
        # Global counters are checked when all score events have arrived.
        global_ok=latest.get('totalAttacks',0)==output and latest.get('totalDamage',0)==damage and latest.get('invalidSequenceCount',0)==invalid and latest.get('bossHp',1000000000)==max(0,1000000000-damage)
        state_errors=q("""SELECT count(*) FROM (
            SELECT payload,seq,sum(applied) OVER (PARTITION BY player ORDER BY seq ROWS UNBOUNDED PRECEDING) running
            FROM events WHERE topic='bossraid-score-updates')
            WHERE json_extract(payload,'$.combo') IS NOT seq OR json_extract(payload,'$.lastSequence') IS NOT seq OR json_extract(payload,'$.playerDamage') IS NOT running""")
        clean=expected>0 and expected==output==integrity and not any((duplicates,missing,extra,gaps,mismatches,integrity_errors,invalid,state_errors)) and global_ok
        leaders=self.db.execute("SELECT player,sum(applied) d FROM events WHERE topic='bossraid-score-updates' GROUP BY player ORDER BY d DESC LIMIT 10").fetchall()
        return dict(expectedAttacks=expected,uniqueProcessedAttacks=output,integrityEvents=integrity,
            duplicateAttacks=duplicates,missingAttacks=missing,unexpectedOutputs=extra,missingSequences=gaps,
            invalidSequences=invalid,checksum='OK' if clean else ('MISMATCH' if mismatches or duplicates or invalid or extra else 'PENDING'),
            mismatches=mismatches,playerStateErrors=state_errors,globalStateMatch=global_ok,integrityErrors=integrity_errors,totalDamage=damage,
            bossHp=latest.get('bossHp',1000000000),bossMaxHp=1000000000,version=latest.get('version','waiting'),
            leaderboard=[dict(player=p,damage=d) for p,d in leaders],proofPass=clean)

def proof_ready(report,status,snapshot_revision,now):
    return bool(report['proofPass'] and snapshot_revision==status.get('evidenceRevision')
        and not status.get('snapshotError') and status.get('ready')
        and status.get('consumerLag')==0 and status.get('kafkaLag')==0
        and now-status.get('lagUpdatedAt',0)<10 and now-status.get('telemetryUpdatedAt',0)<15)
