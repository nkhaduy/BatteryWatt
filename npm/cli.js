#!/usr/bin/env node
'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const https = require('node:https');
const { execFileSync } = require('node:child_process');

const REPOSITORY = 'nkhaduy/BatteryWatt';

function usage() {
  console.log(`BatteryWatt native macOS installer

Usage:
  npx batterywatt install [--force]
  npx batterywatt uninstall
  npx batterywatt help

The installer downloads an official GitHub Release DMG, verifies its SHA-256,
copies BatteryWatt.app to ~/Applications, and launches it. npm install has no
installation side effects.`);
}

function request(url, responseType = 'text') {
  return new Promise((resolve, reject) => {
    const requestOptions = {
      headers: {
        'User-Agent': 'batterywatt-npm-helper',
        Accept: responseType === 'json' ? 'application/vnd.github+json' : 'application/octet-stream'
      }
    };
    https.get(url, requestOptions, response => {
      if (response.statusCode >= 300 && response.statusCode < 400 && response.headers.location) {
        response.resume();
        request(response.headers.location, responseType).then(resolve, reject);
        return;
      }
      if (response.statusCode !== 200) {
        response.resume();
        reject(new Error(`Download failed with HTTP ${response.statusCode}: ${url}`));
        return;
      }
      const chunks = [];
      response.on('data', chunk => chunks.push(chunk));
      response.on('end', () => {
        const body = Buffer.concat(chunks);
        try {
          resolve(responseType === 'json' ? JSON.parse(body.toString('utf8')) : body);
        } catch (error) {
          reject(new Error(`Could not parse response from ${url}: ${error.message}`));
        }
      });
    }).on('error', reject);
  });
}

function writeDownload(url, destination) {
  return request(url).then(buffer => fs.writeFileSync(destination, buffer));
}

function checksumFor(checksumFile, filename) {
  const lines = fs.readFileSync(checksumFile, 'utf8').split(/\r?\n/);
  const line = lines.find(value => value.trim().endsWith(` ${filename}`) || value.trim().endsWith(` *${filename}`));
  if (!line) throw new Error(`No checksum found for ${filename}`);
  const match = line.trim().match(/^([a-fA-F0-9]{64})\s+\*?(.+)$/);
  if (!match || match[2] !== filename) throw new Error(`Invalid checksum entry for ${filename}`);
  return match[1].toLowerCase();
}

function verifyChecksum(file, expected) {
  const actual = crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
  if (actual !== expected) {
    throw new Error(`Checksum mismatch for ${path.basename(file)}: expected ${expected}, got ${actual}`);
  }
}

async function latestRelease() {
  return request(`https://api.github.com/repos/${REPOSITORY}/releases/latest`, 'json');
}

function asset(release, name) {
  const result = release.assets && release.assets.find(item => item.name === name);
  if (!result) throw new Error(`Release ${release.tag_name} does not contain ${name}`);
  return result.browser_download_url;
}

function mountedVolume(dmgPath) {
  const output = execFileSync('/usr/bin/hdiutil', ['attach', '-nobrowse', '-readonly', dmgPath], { encoding: 'utf8' });
  const line = output.split(/\r?\n/).reverse().find(value => value.includes('/Volumes/'));
  if (!line) throw new Error('The DMG mounted without a readable volume path');
  return line.slice(line.indexOf('/Volumes/')).trim();
}

function install(force) {
  if (process.platform !== 'darwin') throw new Error('BatteryWatt is available only on macOS.');
  if (!['arm64', 'x64'].includes(process.arch)) throw new Error(`Unsupported macOS architecture: ${process.arch}`);

  return latestRelease().then(async release => {
    const version = release.tag_name.replace(/^v/, '');
    const dmgName = `BatteryWatt-${version}.dmg`;
    const sumsName = 'SHA256SUMS.txt';
    const tempDirectory = fs.mkdtempSync(path.join(os.tmpdir(), 'batterywatt-'));
    const dmgPath = path.join(tempDirectory, dmgName);
    const sumsPath = path.join(tempDirectory, sumsName);
    let volumePath;
    try {
      console.log(`Downloading BatteryWatt ${version} from GitHub Releases...`);
      await writeDownload(asset(release, dmgName), dmgPath);
      await writeDownload(asset(release, sumsName), sumsPath);
      verifyChecksum(dmgPath, checksumFor(sumsPath, dmgName));
      volumePath = mountedVolume(dmgPath);
      const source = path.join(volumePath, 'BatteryWatt.app');
      if (!fs.existsSync(source)) throw new Error('The release DMG does not contain BatteryWatt.app');

      const applications = path.join(os.homedir(), 'Applications');
      const destination = path.join(applications, 'BatteryWatt.app');
      if (fs.existsSync(destination) && !force) {
        throw new Error(`${destination} already exists; use install --force to replace it`);
      }
      fs.mkdirSync(applications, { recursive: true });
      execFileSync('/usr/bin/ditto', [source, destination], { stdio: 'inherit' });
      execFileSync('/usr/bin/open', ['-gj', destination], { stdio: 'inherit' });
      console.log(`Installed ${destination}`);
    } finally {
      if (volumePath) {
        try { execFileSync('/usr/bin/hdiutil', ['detach', volumePath], { stdio: 'ignore' }); } catch (_) {}
      }
      fs.rmSync(tempDirectory, { recursive: true, force: true });
    }
  });
}

function uninstall() {
  if (process.platform !== 'darwin') throw new Error('BatteryWatt is available only on macOS.');
  const destination = path.join(os.homedir(), 'Applications', 'BatteryWatt.app');
  if (!fs.existsSync(destination)) {
    console.log('BatteryWatt is not installed in ~/Applications.');
    return;
  }
  fs.rmSync(destination, { recursive: true, force: true });
  console.log(`Removed ${destination}`);
  console.log('Preferences and optional local history were left untouched.');
}

async function main() {
  const command = process.argv[2] || 'help';
  if (command === 'help' || command === '--help' || command === '-h') {
    usage();
    return;
  }
  if (command === 'install') {
    await install(process.argv.includes('--force'));
    return;
  }
  if (command === 'uninstall') {
    uninstall();
    return;
  }
  usage();
  process.exitCode = 1;
}

main().catch(error => {
  console.error(`BatteryWatt: ${error.message}`);
  process.exitCode = 1;
});
