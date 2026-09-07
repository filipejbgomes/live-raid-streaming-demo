import json, sys, time, urllib.request
last=None;stable=0;report={}
for attempt in range(180):
    try:
        with urllib.request.urlopen(f'http://127.0.0.1:{sys.argv[2]}/metrics-json',timeout=15) as r:report=json.load(r)
        signature=(report['expectedAttacks'],report['uniqueProcessedAttacks'],report['integrityEvents'])
        stable=stable+1 if report['proofPass'] and signature==last else 0
        last=signature
        print(f"Draining: input={signature[0]} output={signature[1]} integrity={signature[2]} lag={report['kafkaLag']} observerLag={report['consumerLag']}",flush=True)
        if stable>=3:break
    except Exception as e:print(f'Waiting for verifier: {e}',flush=True)
    time.sleep(5)
else:
    report['proofPass']=False
with open(sys.argv[1],'w') as f:json.dump(report,f,indent=2)
for key in ['expectedAttacks','uniqueProcessedAttacks','duplicateAttacks','missingAttacks','missingSequences','invalidSequences','checksum','kafkaLag','consumerLag']:
    print(f'{key:26} {report.get(key,"UNAVAILABLE")}')
passed=report.get('proofPass',False) and stable>=3
print('PASS' if passed else 'FAIL — incomplete drain or integrity mismatch; inspect the saved report')
sys.exit(0 if passed else 1)
