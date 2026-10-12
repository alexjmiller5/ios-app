import unittest
from pathlib import Path

class WorkflowTests(unittest.TestCase):
    def test_workflow_dispatch_encrypts_only_artifact_and_always_cleans_plaintext(self):
        import json
        import subprocess
        workflow = Path(__file__).parents[1] / '.github/workflows/build-ios.yml'
        parsed = json.loads(subprocess.check_output([
            'ruby', '-rjson', '-ryaml', '-e', 'puts JSON.generate(YAML.load_file(ARGV[0]))', str(workflow)]))
        triggers = parsed.get('on', parsed.get('true'))
        self.assertEqual(set(triggers), {'workflow_dispatch'})
        self.assertTrue(triggers['workflow_dispatch']['inputs']['artifact_recipient']['required'])
        steps = parsed['jobs']['signed-ipa']['steps']
        uploads = [s for s in steps if s.get('uses', '').startswith('actions/upload-artifact@')]
        self.assertEqual(len(uploads), 1)
        self.assertTrue(uploads[0]['with']['path'].endswith('/App.ipa.age'))
        self.assertNotIn('*', uploads[0]['with']['path'])
        self.assertEqual(uploads[0]['with']['retention-days'], 1)
        encrypt = next(s for s in steps if s.get('name') == 'Encrypt IPA')
        self.assertIn('age --encrypt', encrypt['run'])
        self.assertNotIn('${{ inputs.', encrypt['run'])
        cleanup = next(s for s in steps if s.get('name') == 'Remove plaintext IPA')
        self.assertEqual(cleanup['if'], 'always()')
        self.assertIn('unlink', cleanup['run'])

    def test_check_runs_on_main_and_prs_and_cancels_superseded_runs(self):
        import json
        import subprocess
        workflow = Path(__file__).parents[1] / '.github/workflows/check.yml'
        parsed = json.loads(subprocess.check_output([
            'ruby', '-rjson', '-ryaml', '-e', 'puts JSON.generate(YAML.load_file(ARGV[0]))', str(workflow)]))
        triggers = parsed.get('on', parsed.get('true'))
        self.assertEqual(triggers['push'], {'branches': ['main']})
        self.assertIn('pull_request', triggers)
        self.assertEqual(parsed['concurrency']['group'], '${{ github.workflow }}-${{ github.ref }}')
        self.assertTrue(parsed['concurrency']['cancel-in-progress'])


if __name__ == "__main__":
    unittest.main()
