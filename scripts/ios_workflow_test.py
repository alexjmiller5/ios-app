import unittest
import os
import subprocess
import tempfile
from pathlib import Path

class WorkflowTests(unittest.TestCase):
    def test_ipa_is_published_before_device_install_even_when_phone_is_unreachable(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'justfile').write_text((Path(__file__).parents[1] / 'justfile').read_text())
            (root / 'scripts').mkdir()
            (root / 'bin').mkdir()
            (root / 'App.ipa').touch()
            upload = root / 'scripts/ota-install.py'
            upload.write_text(
                '#!/usr/bin/env python3\nimport os, pathlib, sys\n'
                'with pathlib.Path(os.environ["EVENTS"]).open("a") as log: log.write("upload\\n")\n'
                'sys.exit(int(os.environ["UPLOAD_EXIT"]))\n')
            upload.chmod(0o755)
            install = root / 'bin/xcrun'
            install.write_text('#!/bin/sh\nprintf "install\\n" >> "$EVENTS"\nexit "$INSTALL_EXIT"\n')
            install.chmod(0o755)
            events = root / 'events'
            for upload_exit, install_exit in [(0, 0), (0, 1), (1, 0)]:
                with self.subTest(upload_exit=upload_exit, install_exit=install_exit):
                    events.write_text('')
                    result = subprocess.run(
                        ['just', '--justfile', str(root / 'justfile'), '_install', str(root / 'App.ipa')],
                        env={**os.environ, 'PATH': str(root / 'bin') + os.pathsep + os.environ['PATH'],
                             'IOS_INSTALL_HOST': '', 'IOS_DEVICE_ID': 'fixture-device',
                             'EVENTS': str(events), 'UPLOAD_EXIT': str(upload_exit),
                             'INSTALL_EXIT': str(install_exit)}, capture_output=True, text=True)
                    self.assertEqual(events.read_text().splitlines(),
                                     ['upload'] if upload_exit else ['upload', 'install'])
                    self.assertEqual(result.returncode == 0, upload_exit == install_exit == 0)

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
        archive = next(s for s in steps if s.get('name') == 'Archive and verify')
        self.assertEqual(archive['env']['BUILD_NUMBER'], '${{ github.run_number }}')
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
