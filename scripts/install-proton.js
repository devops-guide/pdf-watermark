const { spawnSync } = require('node:child_process');
const { mkdtempSync, readFileSync, rmSync, writeFileSync } = require('node:fs');
const { tmpdir } = require('node:os');
const { join } = require('node:path');

const version = '0.9.1';
const revision = '838bf006995325037ce5e2068f64c34469f39df1';
const options = { stdio: 'inherit' };

function run(command, args, cwd) {
  const { error, status } = spawnSync(command, args, { ...options, cwd });
  if (error) throw error;
  if (status !== 0) throw new Error(`${command} exited with status ${status}`);
}

function installCompatibleCli() {
  const source = mkdtempSync(join(tmpdir(), 'pdf-watermark-proton-'));
  try {
    run('git', ['init', '--quiet'], source);
    run('git', ['fetch', '--depth=1', 'https://github.com/moonbit-community/proton.git', revision], source);
    run('git', ['checkout', '--quiet', 'FETCH_HEAD'], source);

    // Newer MoonBit core requires an explicit mutable view for file reads.
    for (const name of ['cefsetup/store/cef_download.mbt', 'cli/package/package_updater.mbt']) {
      const path = join(source, name);
      const code = readFileSync(path, 'utf8');
      const patched = code.replace('file.read_into(buffer)', 'file.read_into(buffer.mut_view())');
      if (patched === code) throw new Error(`Proton compatibility patch did not match ${name}`);
      writeFileSync(path, patched);
    }
    run('moon', ['install', './cli'], source);
  } finally {
    rmSync(source, { recursive: true, force: true });
  }
}

try {
  const result = spawnSync('moon', ['install', `moonbit-community/proton_cli@${version}`], {
    encoding: 'utf8',
  });
  if (result.error) throw result.error;
  if (result.status === 0) {
    process.stdout.write(result.stdout);
    process.stderr.write(result.stderr);
  } else {
    const details = result.stdout + result.stderr;
    if (!details.includes('file.read_into(buffer)') || !details.includes('MutArrayView')) {
      throw new Error(details);
    }
    console.log('Installing Proton CLI with the MoonBit mutable-view compatibility patch.');
    installCompatibleCli();
  }
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
