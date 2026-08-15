/* eslint-disable no-console */
/**
 * Flutter APK build dashboard — frontend logic
 *
 * Data sources (all served from docs/ via GitHub Pages):
 *   - latest.json   → most recent build (object)
 *   - history.json  → array of recent builds, newest first
 *   - builds.json   → array of artifact entries per ABI for the latest build
 *   - config.json   → optional override for repo URL, refresh interval, etc.
 */

(() => {
  'use strict';

  const REFRESH_INTERVAL_MS = 60_000;
  const DATA_BASE = '.';
  const DEFAULT_REPO = guessRepo();

  // ---------- State ----------
  let history = [];
  let latest = null;
  let filter = 'all';
  let refreshTimer = null;

  // ---------- Helpers ----------
  function guessRepo() {
    // Pulled from the page URL: <user>.github.io/<repo>/
    const segs = location.pathname.split('/').filter(Boolean);
    return segs[0] || '';
  }

  function el(tag, attrs = {}, ...children) {
    const node = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs)) {
      if (k === 'class') node.className = v;
      else if (k === 'dataset') Object.assign(node.dataset, v);
      else if (k.startsWith('on') && typeof v === 'function') node.addEventListener(k.slice(2).toLowerCase(), v);
      else if (v !== null && v !== undefined) node.setAttribute(k, v);
    }
    for (const c of children.flat()) {
      if (c == null || c === false) continue;
      node.appendChild(typeof c === 'string' ? document.createTextNode(c) : c);
    }
    return node;
  }

  function formatBytes(bytes) {
    if (!bytes || bytes < 1) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(1024));
    return `${(bytes / Math.pow(1024, i)).toFixed(i ? 1 : 0)} ${units[i]}`;
  }

  function formatTime(iso) {
    if (!iso) return '—';
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return iso;
    const delta = (Date.now() - d.getTime()) / 1000;
    if (delta < 60) return `${Math.floor(delta)}s ago`;
    if (delta < 3600) return `${Math.floor(delta / 60)}m ago`;
    if (delta < 86400) return `${Math.floor(delta / 3600)}h ago`;
    if (delta < 604800) return `${Math.floor(delta / 86400)}d ago`;
    return d.toLocaleDateString();
  }

  function formatAbsolute(iso) {
    if (!iso) return '—';
    const d = new Date(iso);
    return Number.isNaN(d.getTime()) ? iso : d.toLocaleString();
  }

  function shortSha(sha) {
    return sha ? sha.slice(0, 7) : '—';
  }

  function repoUrl() {
    const repo = DEFAULT_REPO;
    return repo ? `https://github.com/${repo}` : '#';
  }

  function actionsUrl(runId) {
    const repo = DEFAULT_REPO;
    return repo && runId ? `https://github.com/${repo}/actions/runs/${runId}` : '#';
  }

  function artifactUrl(runId, name) {
    const repo = DEFAULT_REPO;
    return repo && runId
      ? `https://github.com/${repo}/actions/runs/${runId}/artifacts`
      : '#';
  }

  // ---------- Data fetch ----------
  async function fetchJSON(path) {
    const res = await fetch(`${DATA_BASE}/${path}`, { cache: 'no-store' });
    if (!res.ok) throw new Error(`${path} → HTTP ${res.status}`);
    return res.json();
  }

  async function loadAll() {
    const [latestData, historyData, buildsData] = await Promise.allSettled([
      fetchJSON('latest.json'),
      fetchJSON('history.json'),
      fetchJSON('builds.json'),
    ]);

    latest = latestData.status === 'fulfilled' ? latestData.value : null;
    history = historyData.status === 'fulfilled' && Array.isArray(historyData.value)
      ? historyData.value
      : [];
    const builds = buildsData.status === 'fulfilled' && Array.isArray(buildsData.value)
      ? buildsData.value
      : [];

    if (!latest && history.length === 0) {
      throw new Error('No build data available yet — push to main to trigger the first build.');
    }
    // If latest.json missing but history exists, use the newest history entry.
    if (!latest && history.length > 0) latest = history[0];

    return { builds };
  }

  // ---------- Render ----------
  function renderHeader() {
    const titleEl = document.getElementById('repo-title');
    const subEl = document.getElementById('repo-subtitle');
    const linkEl = document.getElementById('repo-link');
    if (DEFAULT_REPO) {
      titleEl.textContent = DEFAULT_REPO;
      subEl.textContent = 'Flutter Android APK build status & download portal';
    }
    linkEl.href = repoUrl();
  }

  function renderLatest(builds) {
    const badge = document.getElementById('latest-conclusion');
    const conclusion = (latest.conclusion || 'pending').toLowerCase();
    badge.className = `badge badge-${conclusion === 'success' ? 'success' : conclusion === 'failure' ? 'failure' : 'pending'}`;
    badge.textContent = conclusion;

    const body = document.getElementById('latest-body');
    body.innerHTML = '';
    body.appendChild(el('div', { class: 'meta-row' },
      el('strong', {}, `#${latest.run_number}`),
      el('span', {}, '·'),
      el('span', {}, `Flutter ${latest.flutter_version || '—'}`),
      el('span', {}, '·'),
      el('span', {}, `${latest.build_mode || 'release'} build${latest.split_per_abi === 'true' ? ' (split per ABI)' : ''}`),
    ));
    body.appendChild(el('div', { class: 'meta-row' },
      el('strong', {}, 'Commit:'),
      el('a', { href: `${repoUrl()}/commit/${latest.sha}`, target: '_blank', rel: 'noopener' }, shortSha(latest.sha)),
      el('span', {}, '·'),
      el('span', {}, `by ${latest.commit_author || latest.actor || '—'}`),
    ));
    if (latest.commit_message) {
      body.appendChild(el('div', { class: 'commit-msg' }, latest.commit_message));
    }
    body.appendChild(el('div', { class: 'meta-row' },
      el('strong', {}, 'Finished:'),
      el('span', { title: formatAbsolute(latest.finished_at) }, formatTime(latest.finished_at)),
    ));
    body.appendChild(el('div', { class: 'meta-row' },
      el('a', { href: actionsUrl(latest.run_id), target: '_blank', rel: 'noopener' },
        '🔗 View run on GitHub →'),
    ));

    renderDownloadGrid(builds);
  }

  function renderDownloadGrid(builds) {
    const grid = document.getElementById('latest-downloads');
    grid.innerHTML = '';

    const apks = (latest.apks && latest.apks.length > 0)
      ? latest.apks
      : builds.map(b => ({
          file: b.file,
          size: b.size,
          sha256: b.sha256,
          abi: b.abi,
        }));

    if (!apks.length) {
      grid.appendChild(el('p', { class: 'subtitle' }, 'No APKs in this build.'));
      return;
    }

    // If we don't have actual artifact URLs (only metadata), point to the Actions run page
    const runLink = artifactUrl(latest.run_id, latest.run_number);

    for (const apk of apks) {
      const abi = apk.abi || detectAbi(apk.file);
      const a = el('a', {
        class: 'download-btn',
        href: runLink,
        target: '_blank',
        rel: 'noopener',
        title: apk.sha256 ? `SHA-256: ${apk.sha256}` : apk.file,
      },
        el('span', { class: 'abi' }, abi),
        el('span', { class: 'filename' }, apk.file),
        el('span', { class: 'filesize' }, formatBytes(apk.size)),
      );
      grid.appendChild(a);
    }

    // Master "all artifacts" button
    grid.appendChild(el('a', {
      class: 'download-btn',
      href: runLink,
      target: '_blank',
      rel: 'noopener',
      style: 'border-color: var(--flutter-light-blue);',
    },
      el('span', { class: 'abi' }, 'All artifacts'),
      el('span', { class: 'filename' }, 'Open Actions run to download'),
      el('span', { class: 'filesize' }, `${apks.length} file${apks.length === 1 ? '' : 's'}`),
    ));
  }

  function detectAbi(filename) {
    if (!filename) return 'apk';
    const m = filename.match(/-(arm64-v8a|armeabi-v7a|x86_64)\.apk$/);
    return m ? m[1] : 'universal';
  }

  function renderStats() {
    const total = history.length;
    const successes = history.filter(h => (h.conclusion || 'success') === 'success').length;
    const rate = total ? `${Math.round((successes / total) * 100)}%` : '—';
    const lastSuccess = history.find(h => (h.conclusion || 'success') === 'success');

    // Avg build time — needs started_at + finished_at (workflow currently only sets finished_at,
    // so we can only display if data is present).
    let avgTime = '—';
    const timed = history.filter(h => h.started_at && h.finished_at);
    if (timed.length) {
      const totalMs = timed.reduce((acc, h) => {
        return acc + (new Date(h.finished_at).getTime() - new Date(h.started_at).getTime());
      }, 0);
      const avgMs = totalMs / timed.length;
      avgTime = formatDuration(avgMs);
    }

    document.getElementById('stat-total').textContent = total || '0';
    document.getElementById('stat-success').textContent = total ? rate : '—';
    document.getElementById('stat-avg-time').textContent = avgTime;
    document.getElementById('stat-last-success').textContent = lastSuccess
      ? formatTime(lastSuccess.finished_at)
      : '—';
  }

  function formatDuration(ms) {
    const s = Math.round(ms / 1000);
    if (s < 60) return `${s}s`;
    const m = Math.floor(s / 60);
    const rem = s % 60;
    return rem ? `${m}m ${rem}s` : `${m}m`;
  }

  function renderHistory() {
    const list = document.getElementById('history-list');
    list.innerHTML = '';

    const filtered = history.filter(h => {
      if (filter === 'all') return true;
      return (h.conclusion || 'success') === filter;
    });

    if (filtered.length === 0) {
      list.appendChild(el('p', { class: 'subtitle' }, 'No builds match this filter.'));
      return;
    }

    for (const h of filtered.slice(0, 50)) {
      const conclusion = (h.conclusion || 'pending').toLowerCase();
      const item = el('div', {
        class: 'history-item',
        role: 'button',
        tabindex: '0',
        'data-run-id': h.run_id,
      },
        el('span', { class: `badge badge-${conclusion === 'success' ? 'success' : 'failure'}` },
          conclusion === 'success' ? '✓' : '✗'),
        el('div', { class: 'run-info' },
          el('div', { class: 'run-message' },
            `#${h.run_number} · ${h.commit_message || '(no message)'}`),
          el('div', { class: 'run-meta' },
            el('span', {}, shortSha(h.sha)),
            el('span', {}, `by ${h.commit_author || h.actor || '—'}`),
            el('span', {}, `${(h.apks || []).length} APK${(h.apks || []).length === 1 ? '' : 's'}`),
          ),
        ),
        el('span', { class: 'run-time', title: formatAbsolute(h.finished_at) },
          formatTime(h.finished_at)),
        el('a', {
          class: 'run-link',
          href: actionsUrl(h.run_id),
          target: '_blank',
          rel: 'noopener',
          title: 'Open run on GitHub',
          onclick: (e) => e.stopPropagation(),
        }, '↗'),
      );

      item.addEventListener('click', () => showDetails(h));
      item.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          showDetails(h);
        }
      });

      list.appendChild(item);
    }
  }

  function showDetails(build) {
    const modal = document.getElementById('modal');
    const body = document.getElementById('modal-body');

    body.innerHTML = '';
    body.appendChild(buildDetailTable(build));

    modal.classList.remove('hidden');
  }

  function buildDetailTable(build) {
    const rows = [
      ['Run', `#${build.run_number}`, actionsUrl(build.run_id)],
      ['Status', build.conclusion || 'pending', null],
      ['Branch', build.ref_name, `${repoUrl()}/tree/${build.ref_name}`],
      ['Commit', `${shortSha(build.sha)} — ${build.commit_message || ''}`, `${repoUrl()}/commit/${build.sha}`],
      ['Author', build.commit_author || '—', null],
      ['Triggered by', build.actor || '—', `${repoUrl()}/${build.actor}`],
      ['Build mode', build.build_mode || 'release', null],
      ['Split per ABI', build.split_per_abi || 'false', null],
      ['Flutter', build.flutter_version || '—', null],
      ['Java', build.java_version || '—', null],
      ['Started', formatAbsolute(build.started_at), null],
      ['Finished', formatAbsolute(build.finished_at), null],
    ];

    const table = el('table');
    for (const [k, v, link] of rows) {
      const tr = el('tr');
      tr.appendChild(el('th', {}, k));
      const td = el('td');
      if (link && v) {
        td.appendChild(el('a', { href: link, target: '_blank', rel: 'noopener' }, String(v)));
      } else {
        td.textContent = v;
      }
      tr.appendChild(td);
      table.appendChild(tr);
    }

    if (build.apks && build.apks.length) {
      table.appendChild(el('tr', {},
        el('th', {}, 'Artifacts'),
        el('td', {},
          ...build.apks.map(a => el('div', { style: 'margin-bottom: 8px;' },
            el('code', {}, a.file),
            el('br'),
            el('small', { class: 'subtitle' },
              `${formatBytes(a.size)} · SHA-256: ${a.sha256 ? a.sha256.slice(0, 12) + '…' : '—'}`),
          )),
        ),
      ));
    }

    return table;
  }

  function hideModal() {
    document.getElementById('modal').classList.add('hidden');
  }

  // ---------- Main ----------
  async function refresh() {
    const refreshIcon = document.getElementById('refresh-icon');
    const refreshBtn = document.getElementById('refresh-btn');
    refreshIcon.textContent = '⏳';
    refreshBtn.disabled = true;

    try {
      const { builds } = await loadAll();
      document.getElementById('loading').classList.add('hidden');
      document.getElementById('error-banner').classList.add('hidden');
      document.getElementById('dashboard').classList.remove('hidden');

      renderHeader();
      renderLatest(builds);
      renderStats();
      renderHistory();
    } catch (err) {
      console.error('Refresh failed:', err);
      document.getElementById('loading').classList.add('hidden');
      const banner = document.getElementById('error-banner');
      banner.textContent = `Couldn't load build data: ${err.message}`;
      banner.classList.remove('hidden');
    } finally {
      refreshIcon.textContent = '🔄';
      refreshBtn.disabled = false;
    }
  }

  function bindUI() {
    document.getElementById('refresh-btn').addEventListener('click', refresh);

    document.querySelectorAll('.filter-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        filter = btn.dataset.filter;
        renderHistory();
      });
    });

    document.querySelectorAll('[data-close-modal]').forEach(el => {
      el.addEventListener('click', hideModal);
    });
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') hideModal();
    });
  }

  function start() {
    renderHeader();
    bindUI();
    refresh();
    refreshTimer = setInterval(refresh, REFRESH_INTERVAL_MS);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', start);
  } else {
    start();
  }
})();
