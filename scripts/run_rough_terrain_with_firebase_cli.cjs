#!/usr/bin/env node
// Optional credential bridge: use an existing Firebase CLI login in memory only.
// The Python migration remains the single implementation of planning and writes.
const path = require('node:path');
const { spawnSync } = require('node:child_process');

(async () => {
  // Make a global Firebase CLI installation discoverable with NODE_PATH=$(npm root -g).
  const auth = require('firebase-tools/lib/auth.js');
  const account = auth.getGlobalDefaultAccount();
  if (!account?.tokens) throw new Error('Firebase CLI login is required');
  const token = await auth.getAccessToken(account.tokens.refresh_token, [
    'https://www.googleapis.com/auth/cloud-platform',
  ]);
  if (!token?.access_token) throw new Error('Firebase CLI credential refresh failed');

  // Credentials never appear in command arguments, stdout or files. The child
  // removes its short-lived credential from the environment before running the script.
  const bootstrap = `import os, runpy, sys
from google.cloud import firestore
from google.oauth2.credentials import Credentials
credential = Credentials(os.environ.pop('_RTC_CLI_ACCESS_TOKEN'))
original_client = firestore.Client
def authenticated_client(*args, **kwargs):
    kwargs['credentials'] = credential
    return original_client(*args, **kwargs)
firestore.Client = authenticated_client
sys.argv = ['scripts/add_rough_terrain_crane.py'] + sys.argv[1:]
runpy.run_path('scripts/add_rough_terrain_crane.py', run_name='__main__')`;
  const result = spawnSync(process.env.PYTHON || 'python', [
    '-c', bootstrap, ...process.argv.slice(2),
  ], {
    cwd: path.resolve(__dirname, '..'),
    env: { ...process.env, PYTHONIOENCODING: 'utf-8', _RTC_CLI_ACCESS_TOKEN: token.access_token },
    encoding: 'utf-8',
  });
  // The child emits the migration report only; never emit the auth object.
  process.stdout.write(result.stdout || '');
  process.stderr.write(result.stderr || '');
  if (result.error) throw new Error(`Could not launch Python: ${result.error.message}`);
  process.exitCode = result.status ?? 1;
})().catch((error) => {
  process.stderr.write(`${error.message}\n`);
  process.exitCode = 1;
});
