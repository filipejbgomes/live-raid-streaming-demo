import importlib.util, pathlib, unittest
spec=importlib.util.spec_from_file_location('proof',pathlib.Path(__file__).resolve().parents[1]/'apps/raid-verifier/proof.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class ProofTests(unittest.TestCase):
    def setUp(self):self.p=m.Proof(':memory:')
    def event(self,n=1,version='v1'):
        applied=10*(2 if version=='v2' and n%10==0 else 1)
        return dict(eventId=f'p:attack-{n:08d}',playerId='p',sequence=n,damage=10,createdAtEpochMs=1,generatorId='g',valid=True,version=version,appliedDamage=applied,totalAttacks=n,totalDamage=n*10+(10 if version=='v2' and n>=10 else 0),invalidSequenceCount=0,bossHp=1000000000-n*10-(10 if version=='v2' and n>=10 else 0),combo=n,lastSequence=n,playerDamage=n*10+(10 if version=='v2' and n>=10 else 0))
    def add(self,e,topics=None):
        for t in topics or ['bossraid-attacks','bossraid-score-updates','bossraid-integrity']:self.p.ingest(t,0,e['sequence']-1,e)
    def test_empty_never_passes(self):self.assertFalse(self.p.report()['proofPass'])
    def test_matching_passes(self):self.add(self.event());self.assertTrue(self.p.report()['proofPass'])
    def test_missing_output_fails(self):self.add(self.event(),['bossraid-attacks']);self.assertEqual(self.p.report()['missingAttacks'],1)
    def test_duplicate_distinct_offset_fails(self):
        e=self.event();self.add(e);self.p.ingest('bossraid-score-updates',0,2,e);self.assertEqual(self.p.report()['duplicateAttacks'],1)
    def test_replayed_offset_is_not_duplicate(self):self.add(self.event());self.add(self.event());self.assertTrue(self.p.report()['proofPass'])
    def test_corrupt_payload_fails(self):
        e=self.event();self.add(e,['bossraid-attacks']);e['damage']=20;self.add(e,['bossraid-score-updates','bossraid-integrity']);self.assertEqual(self.p.report()['checksum'],'MISMATCH')
    def test_sequence_gap_fails(self):self.add(self.event(2));self.assertEqual(self.p.report()['missingSequences'],1);self.assertFalse(self.p.report()['proofPass'])
    def test_upgrade_bonus(self):
        for n in range(1,11):self.add(self.event(n,'v1' if n<10 else 'v2'))
        self.assertTrue(self.p.report()['proofPass']);self.assertEqual(self.p.report()['totalDamage'],110)
    def test_wrong_bonus_fails(self):
        for n in range(1,10):self.add(self.event(n))
        e=self.event(10,'v2');e['appliedDamage']=10;self.add(e);self.assertFalse(self.p.report()['proofPass'])
    def test_integrity_payload_disagreement_fails(self):
        e=self.event();self.add(e,['bossraid-attacks','bossraid-score-updates']);e['bossHp']=7;self.add(e,['bossraid-integrity']);self.assertFalse(self.p.report()['proofPass'])
    def test_global_state_loss_fails(self):
        self.add(self.event());e=self.event(2);e['totalDamage']=10;self.add(e);self.assertFalse(self.p.report()['proofPass'])
    def test_unexpected_output_fails(self):self.add(self.event(),['bossraid-score-updates','bossraid-integrity']);self.assertFalse(self.p.report()['proofPass'])
    def test_player_state_loss_fails(self):
        self.add(self.event());e=self.event(2);e['playerDamage']=10;self.add(e);self.assertFalse(self.p.report()['proofPass'])
    def test_stale_snapshot_cannot_pass(self):
        status=dict(evidenceRevision=2,ready=True,consumerLag=0,kafkaLag=0,lagUpdatedAt=100,telemetryUpdatedAt=100)
        self.assertFalse(m.proof_ready({'proofPass':True},status,1,101))
        self.assertTrue(m.proof_ready({'proofPass':True},status,2,101))
        self.assertFalse(m.proof_ready({'proofPass':True},status,2,120))
    def tearDown(self):self.p.db.close()
if __name__=='__main__':unittest.main()
