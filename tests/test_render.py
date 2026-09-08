import os, pathlib, subprocess, unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class RenderTests(unittest.TestCase):
    def render(self,*files,**settings):
        env={k:v for k,v in os.environ.items() if k not in ('IMAGE_REGISTRY','IMAGE_TAG','STORAGE_CLASS','IMAGE_PULL_SECRET')};env.update(settings)
        return subprocess.check_output(['python3',str(ROOT/'scripts/render.py'),*[str(ROOT/f) for f in files]],env=env,text=True)
    def test_default_storage_and_local_images(self):
        s=self.render('k8s/demo/verifier.yaml');self.assertNotIn('storageClassName',s);self.assertIn('bossraid-verifier:local',s)
    def test_registry_upgrade_and_pull_secret(self):
        s=self.render('k8s/flink/job.yaml',IMAGE_REGISTRY='registry.example/team/',IMAGE_TAG='test-42',IMAGE_PULL_SECRET='pull')
        self.assertIn('registry.example/team/bossraid-score-engine-v1:test-42',s);self.assertIn('"name": "pull"',s);self.assertNotIn('file://',s)
    def test_storage_class_both_kinds(self):
        s=self.render('k8s/demo/verifier.yaml','k8s/kafka/kafka.yaml',STORAGE_CLASS='fast-csi');self.assertIn('storageClassName: "fast-csi"',s);self.assertIn('class: "fast-csi"',s)
