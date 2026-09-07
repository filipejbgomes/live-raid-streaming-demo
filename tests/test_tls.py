import os,pathlib,subprocess,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class TLSTests(unittest.TestCase):
    def render(self,kind='tls',**overrides):
        env={**os.environ,'DASHBOARD_HOST':'raid.example.org','ACME_EMAIL':'ops@example.org','INGRESS_CLASS':'traefik','ACME_ENV':'production'};env.update(overrides)
        return subprocess.run(['python3',str(ROOT/'scripts/tls-resources.py'),kind],env=env,text=True,capture_output=True)
    def test_production(self):
        r=self.render();self.assertEqual(r.returncode,0);self.assertIn('https://acme-v02.api.letsencrypt.org/directory',r.stdout);self.assertIn('rotationPolicy: Always',r.stdout)
    def test_staging_separate_account(self):self.assertIn('raid-letsencrypt-staging-account',self.render(ACME_ENV='staging').stdout)
    def test_ingress_uses_tls(self):self.assertIn('secretName: "raid-dashboard-tls"',self.render('ingress').stdout)
    def test_invalid_domain_fails(self):self.assertNotEqual(self.render(DASHBOARD_HOST='https://bad/path').returncode,0)
    def test_no_email_fails(self):self.assertNotEqual(self.render(ACME_EMAIL='').returncode,0)
