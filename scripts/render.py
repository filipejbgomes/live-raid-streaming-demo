"""Small textual renderer: YAML remains reviewable and needs no third-party host package."""
import json, os, pathlib, sys
registry=os.getenv('IMAGE_REGISTRY','').rstrip('/')
tag=os.getenv('IMAGE_TAG','local')
for arg in sys.argv[1:]:
    data=pathlib.Path(arg).read_text()
    for app in ('bossraid-player-generator','bossraid-verifier','bossraid-dashboard','bossraid-score-engine-v1','bossraid-score-engine-v2'):
        data=data.replace(app+':local',(registry+'/' if registry else '')+app+':'+tag)
    storage=os.getenv('STORAGE_CLASS','')
    lines=[]
    for line in data.splitlines():
        if '__STORAGE_CLASS__' in line:
            if not storage:continue
            line=line.replace('__STORAGE_CLASS__',json.dumps(storage))
        lines.append(line)
    data='\n'.join(lines)
    secret=os.getenv('IMAGE_PULL_SECRET','')
    if secret:data=data.replace('imagePullSecrets: []','imagePullSecrets: '+json.dumps([{'name':secret}]))
    print('---\n'+data)
