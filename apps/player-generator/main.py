import hashlib, json, logging, os, random, signal, time, uuid
from kafka import KafkaProducer
logging.basicConfig(level=logging.INFO)
running = True
def stop(*_):
    global running
    running = False
signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)
# A fresh incarnation owns a fresh player namespace, including after a pod restart.
generator = os.getenv('HOSTNAME', 'generator') + '-' + uuid.uuid4().hex[:12]
players = int(os.getenv('PLAYERS', '500'))
rate = int(os.getenv('RATE', '500'))
ADJECTIVES=('amber','brave','cosmic','daring','ember','frost','golden','lucky','mighty','nimble','rapid','silent','wild','zen')
MALAYSIAN_STATES=('johor','kedah','kelantan','melaka','pahang','perak','perlis','sabah','sarawak','selangor','terengganu')
MALAYSIAN_CITIES=('bintulu','cyberjaya','ipoh','kangar','kluang','kuantan','kuching','kulim','miri','muar','putrajaya','sandakan','seremban','sibu','taiping','tawau')
ANIMALS=('badger','falcon','ferret','fox','gecko','otter','panda','rabbit','raven','tiger','walrus','wolf','yak','zebra')
PLAYER_PREFIXES=ADJECTIVES+MALAYSIAN_STATES+MALAYSIAN_CITIES
def player_handle(index):
    """Stable for this player incarnation; the 12-hex suffix keeps handles unique in practice."""
    digest=hashlib.sha256(f'{generator}:{index}'.encode()).digest()
    return f'@{PLAYER_PREFIXES[digest[0]%len(PLAYER_PREFIXES)]}_{ANIMALS[digest[1]%len(ANIMALS)]}_{digest[2:8].hex()}'
producer = KafkaProducer(bootstrap_servers=os.getenv('BOOTSTRAP', 'bossraid-kafka-bootstrap.kafka:9092'),
    enable_idempotence=True, acks='all', linger_ms=10,
    key_serializer=lambda x:x.encode(), value_serializer=lambda x:json.dumps(x).encode())
seq = [0] * players
logging.info('Starting %s: %d players, target %d attacks/s', generator, players, rate)
try:
    while running:
        start = time.monotonic()
        pending = []
        for _ in range(max(1, rate // 10)):
            i = random.randrange(players)
            seq[i] += 1
            player = player_handle(i)
            event = dict(eventId=f'{player}:attack-{seq[i]:08d}', playerId=player,
                sequence=seq[i], damage=random.randint(10, 25),
                createdAtEpochMs=int(time.time()*1000), generatorId=generator)
            pending.append(producer.send('bossraid-attacks', key=player, value=event))
        for future in pending:
            future.get(timeout=30)  # Fail visibly on uncertainty; never skip failed sends.
        time.sleep(max(0, .1 - (time.monotonic()-start)))
finally:
    producer.flush(timeout=30)
    producer.close(timeout=30)
    logging.info('Generator stopped and acknowledged sends flushed')
