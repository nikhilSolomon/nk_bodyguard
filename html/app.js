const $ = (s) => document.querySelector(s);
const panel = $('#panel');
const resName = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'nk_bodyguard';

let lastData = null;
let selected = null;        // selected guard index (Squad page)
let dismissArmed = null;
let drag = null;            // { slot, moved }
let customDraft = null;     // offsets while dragging

const TITLES = {
  home: ['Overview', 'Squad status at a glance'],
  squad: ['Squad', 'Click a row for per-guard actions'],
  formation: ['Formation', 'How your guards arrange themselves around you'],
  vehicle: ['Vehicle', 'Seats, chauffeur, escort and air support'],
  settings: ['Settings', 'Squad behaviour and panel preferences'],
};

function post(name, data) {
  return fetch(`https://${resName}/${name}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data || {}),
  }).catch(() => {});
}
const setActive = (sel, attr, v) => document.querySelectorAll(sel).forEach(b => b.classList.toggle('active', b.dataset[attr] === String(v)));
const fmtTime = (ms) => new Date(ms).toTimeString().slice(0, 8);

function fillSelect(sel, items, value, randomOpt) {
  const want = (randomOpt ? 1 : 0) + items.length;
  if (sel.options.length !== want) {
    sel.innerHTML = (randomOpt ? '<option value="random">🎲 Random</option>' : '') + items.map(i => `<option value="${i.id}">${i.label}</option>`).join('');
  }
  sel.value = value;
}

// ---- formation geometry (mirrors client.lua) ----
function presetOffset(i, formation, spacing, n) {
  const side = (i % 2 === 1) ? -1 : 1;
  const rank = Math.ceil(i / 2);
  if (formation === 1) { const a = (i - 1) * (2 * Math.PI / Math.max(4, n)); return [Math.sin(a) * spacing * 1.4, Math.cos(a) * spacing * 1.4]; }
  if (formation === 2) return [side * spacing * rank, -spacing * rank];
  if (formation === 3) return [side * spacing * rank, 0];
  return [side * spacing * 0.8, -spacing * rank];
}

// Current (applied) offsets for slot i, from the active formation
function activeOffset(d, i) {
  const n = Math.max(d.guards.length, 1);
  const o = d.formation === 4 && d.settings.customOffsets ? (d.settings.customOffsets[i] || d.settings.customOffsets[String(i)]) : null;
  if (o && typeof o.x === 'number') return [o.x, o.y];
  return presetOffset(i, d.formation === 4 ? 0 : d.formation, d.settings.spacing, n);
}

function seedDraft(d, fromFormation) {
  const n = Math.max(d.guards.length, 1);
  const out = {};
  for (let i = 1; i <= d.max; i++) {
    const [x, y] = fromFormation === undefined ? activeOffset(d, i) : presetOffset(i, fromFormation, d.settings.spacing, n);
    out[i] = { x, y };
  }
  return out;
}

function setApplyEnabled(on) { const b = $('#formApply'); b.disabled = !on; b.textContent = on ? '✔ Apply formation (guards walk into place)' : '✔ Apply formation'; }

function drawFormation(d) {
  const svg = $('#formGrid');
  const S = 320, C = S / 2, PX = 20; // 20 px per metre, ±8 m
  let out = '';
  for (let m = -8; m <= 8; m++) {
    const p = C + m * PX;
    out += `<line class="${m === 0 ? 'gm' : 'gl'}" x1="${p}" y1="0" x2="${p}" y2="${S}"/><line class="${m === 0 ? 'gm' : 'gl'}" x1="0" y1="${p}" x2="${S}" y2="${p}"/>`;
  }
  out += `<polygon class="arrow" points="${C},${C - 16} ${C - 5},${C - 7} ${C + 5},${C - 7}"/>`;
  out += `<circle class="me" cx="${C}" cy="${C}" r="7"/>`;
  // only living guards get a dot; slot i belongs to the i-th living guard
  const alive = d.guards.filter(g => !g.dead);
  alive.forEach((g, idx) => {
    const i = idx + 1;
    const o = customDraft ? customDraft[i] : null;
    const [x, y] = o ? [o.x, o.y] : activeOffset(d, i);
    const px = C + x * PX, py = C - y * PX;
    out += `<circle class="dot ${i % 2 ? '' : 'alt'} ${customDraft ? 'draft' : ''}" data-slot="${i}" cx="${px}" cy="${py}" r="9"><title>${g.name}</title></circle><text class="lbl" x="${px}" y="${py + 3.5}" text-anchor="middle">${i}</text>`;
  });
  if (!alive.length) out += `<text class="lbl" x="${C}" y="${C + 40}" text-anchor="middle">no guards alive</text>`;
  svg.innerHTML = out;
}

function svgPoint(svg, e) {
  const r = svg.getBoundingClientRect();
  return [(e.clientX - r.left) / r.width * 320, (e.clientY - r.top) / r.height * 320];
}

(function setupFormationEditor() {
  const svg = $('#formGrid');
  svg.addEventListener('mousedown', (e) => {
    const dot = e.target.closest('.dot');
    if (!dot || !lastData) return;
    e.preventDefault();
    if (!customDraft) customDraft = seedDraft(lastData);
    drag = { slot: Number(dot.dataset.slot) };
  });
  window.addEventListener('mousemove', (e) => {
    if (!drag || !customDraft) return;
    const [px, py] = svgPoint(svg, e);
    const x = Math.max(-8, Math.min(8, Math.round(((px - 160) / 20) * 2) / 2));
    const y = Math.max(-8, Math.min(8, Math.round(((160 - py) / 20) * 2) / 2));
    customDraft[drag.slot] = { x, y };
    if (lastData) drawFormation(lastData);
  });
  window.addEventListener('mouseup', () => {
    if (!drag) return;
    drag = null;
    setApplyEnabled(true);
  });
  $('#formReset').addEventListener('click', () => {
    if (!lastData) return;
    customDraft = seedDraft(lastData, lastData.formation === 4 ? 0 : lastData.formation);
    drawFormation(lastData); setApplyEnabled(true);
  });
  $('#formMirror').addEventListener('click', () => {
    if (!lastData) return;
    if (!customDraft) customDraft = seedDraft(lastData);
    Object.keys(customDraft).forEach(k => { customDraft[k] = { x: -customDraft[k].x, y: customDraft[k].y }; });
    drawFormation(lastData); setApplyEnabled(true);
  });
  $('#formApply').addEventListener('click', () => {
    if (!customDraft) return;
    post('customformation', { offsets: customDraft });
    customDraft = null; setApplyEnabled(false);
  });
})();

function render(d) {
  lastData = d;
  const alive = d.guards.filter(g => !g.dead);
  const fighting = alive.filter(g => g.state === 'Firing' || g.state === 'Fighting').length;
  const avg = alive.length ? Math.round(alive.reduce((a, g) => a + g.health / g.maxHealth, 0) / alive.length * 100) : null;
  const kills = d.guards.reduce((a, g) => a + (g.kills || 0), 0);

  $('#stAlive').textContent = alive.length;
  $('#stHp').textContent = avg === null ? '–' : avg + '%';
  $('#stKills').textContent = kills;
  $('#stFight').textContent = fighting;
  $('#sideMode').textContent = ({ follow: 'Follow', hold: 'Hold', aggressive: 'Aggressive', passive: 'Hold fire' })[d.mode];
  $('#sideCount').textContent = `${d.guards.length} / ${d.max}`;
  const pill = $('#statePill');
  pill.textContent = fighting ? `${fighting} fighting` : (alive.length ? 'Ready' : 'Idle');
  pill.className = 'pill ' + (fighting ? 'fight' : (alive.length ? 'ok' : ''));

  setActive('button.mode', 'mode', d.mode);
  setActive('button.form', 'formation', d.formation);
  setActive('button.style', 'style', d.driveStyle);
  setActive('button.pos', 'pos', d.settings.pos);
  setActive('button.scale', 'scale', d.settings.scale);
  panel.classList.toggle('pos-left', d.settings.pos === 'left');
  panel.classList.toggle('pos-right', d.settings.pos === 'right');
  document.documentElement.style.setProperty('--scale', d.settings.scale || 1);

  $('#autoDriveBy').checked = !!d.autoDriveBy;
  ['invincible', 'regen', 'reinforce', 'blips'].forEach(k => { document.querySelector(`[data-toggle="${k}"]`).checked = !!d.settings[k]; });
  $('#escortBtn').classList.toggle('active', !!d.escort);
  $('#airBtn').classList.toggle('active', !!d.air);
  const st = $('#driveStatus'); st.textContent = d.driveStatus || ''; st.style.display = d.driveStatus ? 'block' : 'none';
  $('#styleInfo').innerHTML = d.styleInfo || '';

  fillSelect($('#recruitModel'), d.options.models, d.settings.recruitModel, true);
  fillSelect($('#recruitWeapon'), d.options.weapons, d.settings.recruitWeapon, true);
  fillSelect($('#escortVehicle'), d.options.escortVehicles, d.settings.escortVehicle, false);
  const sp = $('#spacing'); if (document.activeElement !== sp) sp.value = d.settings.spacing;
  $('#spacingVal').textContent = `${Number(d.settings.spacing).toFixed(1)} m`;
  const ac = $('#accuracy'); if (document.activeElement !== ac) ac.value = d.settings.accuracy;
  $('#accuracyVal').textContent = d.settings.accuracy;

  // squad table
  const rows = $('#rows');
  $('#rowsEmpty').style.display = d.guards.length ? 'none' : 'block';
  rows.innerHTML = d.guards.map(g => {
    const hp = Math.max(0, Math.min(100, Math.round(g.health / g.maxHealth * 100)));
    const ar = Math.max(0, Math.min(100, Math.round(g.armour / g.maxArmour * 100)));
    const cls = (g.state === 'Firing' || g.state === 'Fighting') ? 'hot' : ((g.state === 'Driving' || g.state === 'Escorting' || g.state === 'Flying') ? 'drv' : '');
    return `<tr data-guard="${g.index}" class="${selected === g.index ? 'sel' : ''} ${g.dead ? 'dead' : ''}">
      <td><b>${g.name}</b></td><td class="state">${g.model} · ${g.weapon}</td>
      <td><div class="bar ${hp < 35 ? 'low' : ''}"><i style="width:${hp}%"></i></div></td>
      <td><div class="bar ar"><i style="width:${ar}%"></i></div></td>
      <td>${g.kills || 0}</td><td class="state ${cls}">${g.state}</td><td class="state">${g.distance} m</td>
      <td><button class="x" data-gaction="dismiss" data-index="${g.index}" title="Dismiss">✕</button></td></tr>`;
  }).join('');
  const sel = d.guards.find(g => g.index === selected);
  $('#guardDetail').style.display = sel ? 'block' : 'none';
  if (sel) $('#detName').textContent = `${sel.name} · ${sel.model} · ${sel.weapon}`;

  // seats
  const names = d.guards.filter(g => !g.dead).map(g => g.name);
  document.querySelectorAll('[data-seat-sel]').forEach(s => {
    const seat = s.dataset.seatSel;
    const want = '<option value="">—</option>' + names.map(n => `<option value="${n}">${n}</option>`).join('');
    if (s.dataset.sig !== want) { s.innerHTML = want; s.dataset.sig = want; }
    s.value = (d.settings.seats && d.settings.seats[seat]) || '';
  });

  // log
  const logEl = $('#log');
  logEl.innerHTML = (d.log && d.log.length) ? d.log.slice().reverse().map(e => `<div class="${e.kind || ''}"><time>${fmtTime(e.t)}</time><span>${e.msg}</span></div>`).join('') : '<div><span>nothing yet</span></div>';

  if (!drag) drawFormation(d);
}

window.addEventListener('message', (e) => {
  const msg = e.data || {};
  if (msg.type === 'open') panel.classList.remove('hidden');
  if (msg.type === 'close') panel.classList.add('hidden');
  if (msg.type === 'update') render(msg);
});

function armDismiss(b) {
  if (dismissArmed) { clearTimeout(dismissArmed); dismissArmed = null; b.textContent = 'Dismiss all'; b.classList.remove('armed'); return true; }
  b.textContent = 'Click again to confirm'; b.classList.add('armed');
  dismissArmed = setTimeout(() => { dismissArmed = null; b.textContent = 'Dismiss all'; b.classList.remove('armed'); }, 3000);
  return false;
}

document.addEventListener('click', (e) => {
  const b = e.target.closest('button');
  if (!b) {
    const row = e.target.closest('tr[data-guard]');
    if (row) { const idx = Number(row.dataset.guard); selected = selected === idx ? null : idx; if (lastData) render(lastData); return; }
    if (!e.target.closest('#panel') && !panel.classList.contains('hidden')) post('action', { action: 'close' });
    return;
  }
  if (e.detail === 0 && e.clientX === 0 && e.clientY === 0) { e.preventDefault(); return; }
  b.blur();
  if (b.id === 'formReset' || b.id === 'formMirror' || b.id === 'formApply') return; // handled by the editor
  if (b.dataset.tab) {
    document.querySelectorAll('.nav').forEach(t => t.classList.toggle('active', t === b));
    document.querySelectorAll('.page').forEach(p => p.classList.toggle('active', p.dataset.page === b.dataset.tab));
    const t = TITLES[b.dataset.tab]; $('#pageTitle').textContent = t[0]; $('#pageSub').textContent = t[1];
    return;
  }
  if (b.dataset.gaction) {
    const idx = b.dataset.index ? Number(b.dataset.index) : selected;
    if (idx) {
      post('guard', { action: b.dataset.gaction, index: idx });
      if (b.dataset.gaction === 'dismiss' || b.dataset.gaction === 'sendhome') selected = null;
    }
    return;
  }
  if (b.dataset.action === 'dismissall' && !armDismiss(b)) return;
  if (b.dataset.action) post('action', { action: b.dataset.action });
  else if (b.dataset.mode) post('mode', { mode: b.dataset.mode });
  else if (b.dataset.formation) post('formation', { formation: Number(b.dataset.formation) });
  else if (b.dataset.style) post('drivestyle', { style: b.dataset.style });
  else if (b.dataset.pos) post('setting', { name: 'pos', value: b.dataset.pos });
  else if (b.dataset.scale) post('setting', { name: 'scale', value: Number(b.dataset.scale) });
});

document.addEventListener('change', (e) => {
  const t = e.target; if (!t || !t.dataset) return;
  if (t.dataset.toggle) post('toggle', { name: t.dataset.toggle, value: t.checked });
  else if (t.dataset.seatSel !== undefined) post('seat', { seat: Number(t.dataset.seatSel), guard: t.value });
  else if (t.dataset.setting) post('setting', { name: t.dataset.setting, value: t.type === 'range' ? Number(t.value) : t.value });
});
document.addEventListener('input', (e) => {
  const t = e.target;
  if (t && t.id === 'spacing') $('#spacingVal').textContent = `${Number(t.value).toFixed(1)} m`;
  if (t && t.id === 'accuracy') $('#accuracyVal').textContent = t.value;
});

function onKey(e) {
  if (e.key === 'Escape' || e.key === 'Esc' || e.keyCode === 27) { e.preventDefault(); post('action', { action: 'close' }); return; }
  if (e.key === ' ' || e.key === 'Enter' || e.key === 'Tab' || e.key === 'Spacebar') { e.preventDefault(); if (document.activeElement && document.activeElement.blur) document.activeElement.blur(); }
}
window.addEventListener('keydown', onKey);
window.addEventListener('keyup', onKey);
