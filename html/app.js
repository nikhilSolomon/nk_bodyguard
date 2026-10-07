const $ = (s) => document.querySelector(s);

// ---------- inline icon set (stroke icons, 24x24 viewBox) ----------
const ICONS = {
  home:    '<path d="M3 11l9-8 9 8v9a2 2 0 0 1-2 2h-4v-7H9v7H5a2 2 0 0 1-2-2z"/>',
  users:   '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0"/><circle cx="17" cy="9" r="2.5"/><path d="M16 14.5a5 5 0 0 1 5.5 5.5"/>',
  hexagon: '<path d="M12 2.5l8.2 4.7v9.6L12 21.5l-8.2-4.7V7.2z"/>',
  car:     '<path d="M4 16v-4.5L6.2 6h11.6L20 11.5V16"/><path d="M3 16h18"/><circle cx="7.5" cy="17.5" r="1.8"/><circle cx="16.5" cy="17.5" r="1.8"/>',
  sliders: '<path d="M4 7h10M18 7h2M4 12h3M11 12h9M4 17h12"/><circle cx="16" cy="7" r="2"/><circle cx="9" cy="12" r="2"/><circle cx="18" cy="17" r="2"/>',
  x:       '<path d="M18 6L6 18M6 6l12 12"/>',
  target:  '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3"/>',
  pin:     '<path d="M12 22s7-6.3 7-12a7 7 0 0 0-14 0c0 5.7 7 12 7 12z"/><circle cx="12" cy="10" r="2.5"/>',
  rally:   '<circle cx="13" cy="3.5" r="1.5"/><path d="M6 22l3.5-7 2.5 2.5V22M14 13.5l4-1.5-1.5-4-3.5 1.5-2 3.5M9.5 8L6 9.5v3"/>',
  shield:  '<path d="M12 2.5l8 3v6.5c0 5-3.4 9.2-8 11-4.6-1.8-8-6-8-11V5.5z"/>',
  hand:    '<path d="M8 12.5V5.5a1.5 1.5 0 0 1 3 0v6M11 11V3.5a1.5 1.5 0 0 1 3 0V11M14 11.5V5.5a1.5 1.5 0 0 1 3 0V13"/><path d="M17 12.5a1.5 1.5 0 0 1 3 0V15a7 7 0 0 1-7 7h-1a7 7 0 0 1-6-3.3L4 14.6a1.6 1.6 0 0 1 2.6-1.9L8 14.5"/>',
  flag:    '<path d="M5 22V4h12l-2.5 4.5L17 13H5"/>',
  zap:     '<path d="M13 2L4 14h7l-1 8 9-12h-7z"/>',
  medic:   '<rect x="3" y="5" width="18" height="15" rx="3"/><path d="M12 9v7M8.5 12.5h7"/>',
  gun:     '<path d="M3 9h14l4-2v4l-4-2M6 9v6h3.5l1.2-3M17 9v2.5"/>',
  plus:    '<path d="M12 5v14M5 12h14"/>',
  map:     '<path d="M2 6.5v15l6.5-3 7 3 6.5-3v-15l-6.5 3-7-3zM8.5 3.5v15M15.5 6.5v15"/>',
  pause:   '<rect x="6" y="4" width="4" height="16" rx="1"/><rect x="14" y="4" width="4" height="16" rx="1"/>',
  wheel:   '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="2.5"/><path d="M12 3v6.5M4.2 15.5l6-2M19.8 15.5l-6-2"/>',
  rotate:  '<path d="M2 5v6h6"/><path d="M3.5 15a9 9 0 1 0 2-9.5L2 11"/>',
  mirror:  '<path d="M12 2v20M4 7.5l4 4.5-4 4.5M20 7.5l-4 4.5 4 4.5"/>',
  check:   '<path d="M20 6L9 17l-5-5"/>',
  down:    '<path d="M12 4v15M5 12l7 7 7-7"/>',
  up:      '<path d="M12 20V5M5 12l7-7 7 7"/>',
  compass: '<circle cx="12" cy="12" r="9"/><path d="M15.5 8.5l-2.2 5-5 2.2 2.2-5z"/>',
  road:    '<path d="M4.5 21l4-18M19.5 21l-4-18M12 3v3.5M12 10v4M12 17.5V21"/>',
  repeat:  '<path d="M17 2l4 4-4 4"/><path d="M3 11V9.5A3.5 3.5 0 0 1 6.5 6H21"/><path d="M7 22l-4-4 4-4"/><path d="M21 13v1.5a3.5 3.5 0 0 1-3.5 3.5H3"/>',
  stop:    '<rect x="5" y="5" width="14" height="14" rx="2.5"/>',
  truck:   '<path d="M2 4.5h13v12H2zM15 9h4l3 3.5V16.5h-7"/><circle cx="6" cy="18" r="2"/><circle cx="18" cy="18" r="2"/>',
  heli:    '<path d="M3 4h17M11.5 4v4M4 12.5h11a4 4 0 0 1 4 4V18H9.5l-5.5-5.5zM9 21h9"/>',
};
const iconSvg = (name) => `<svg viewBox="0 0 24 24" aria-hidden="true">${ICONS[name] || ''}</svg>`;
function applyIcons(root) {
  (root || document).querySelectorAll('i[data-icon]').forEach(i => { if (!i.firstChild) i.innerHTML = iconSvg(i.dataset.icon); });
}
applyIcons();

const panel = $('#panel');
const inGame = (typeof GetParentResourceName === 'function');
const resName = inGame ? GetParentResourceName() : 'nk_bodyguard';

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
const money = (n) => '$' + Math.floor(n || 0).toLocaleString('en-US');

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

  // role: admins get the free recruit tools, citizens see the Agency + prices
  document.body.classList.toggle('role-admin', !!d.admin);
  document.body.classList.toggle('role-citizen', !d.admin);
  if (d.agency) {
    $('#agencyName').textContent = d.agency.name;
    $('#agencyCount').textContent = `${d.agency.active} / ${d.agency.max}`;
    document.querySelectorAll('[data-price]').forEach(s => {
      const v = d.agency.prices[s.dataset.price];
      s.textContent = v ? money(v) + (s.dataset.suffix || '') : '';
    });
  }

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
    const rk = g.rank === 'Legend' ? 'leg' : (g.rank === 'Veteran' ? 'vet' : '');
    const xArmed = armedRow === g.index && Date.now() - armedRowAt < 3000;
    return `<tr data-guard="${g.index}" class="${selected === g.index ? 'sel' : ''} ${g.dead ? 'dead' : ''}">
      <td><b>${g.name}</b><div class="badges"><span class="tbadge" style="--c:${g.tierColor || '#8b95a7'}">${g.tier || 'Admin'}</span><span class="rbadge ${rk}">${g.rank || 'Recruit'}</span></div></td>
      <td class="state">${g.weapon}</td>
      <td><div class="bar ${hp < 35 ? 'low' : ''}"><i style="width:${hp}%"></i></div></td>
      <td><div class="bar ar"><i style="width:${ar}%"></i></div></td>
      <td>${g.kills || 0}</td><td class="state ${cls}">${g.state}</td><td class="state">${g.distance} m</td>
      <td><button class="x ${xArmed ? 'xarmed' : ''}" data-gaction="dismiss" data-index="${g.index}" title="${g.contract ? 'Dismiss (ends the contract)' : 'Dismiss'}">${xArmed ? 'End?' : '✕'}</button></td></tr>`;
  }).join('');
  const sel = d.guards.find(g => g.index === selected);
  $('#guardDetail').style.display = sel ? 'block' : 'none';
  if (sel) $('#detName').textContent = `${sel.name} · ${sel.tier || 'Admin'} · ${sel.rank || 'Recruit'} · ${sel.weapon}`;

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

// ---------- Agency hiring screen ----------
const shop = $('#shop');
const outfitSel = {};      // tier id -> chosen outfit (1-based), kept across re-renders

function srow(label, v, max) {
  return `<div class="srow"><span>${label}</span><div class="bar"><i style="width:${Math.round(v / Math.max(max, 1) * 100)}%"></i></div><span>${v}</span></div>`;
}

function renderShop(d) {
  $('#shopName').textContent = d.name;
  $('#shopBalance').textContent = d.admin ? 'Admin · free' : money(d.balance);
  $('#shopCount').textContent = `${d.active} / ${d.max} contracts`;
  const full = d.active >= d.max || d.squad >= d.squadMax;
  const maxH = Math.max(...d.tiers.map(t => t.health));
  const maxA = Math.max(...d.tiers.map(t => t.armour));
  $('#tiers').innerHTML = d.tiers.map(t => {
    const afford = d.admin || d.balance >= t.price;
    const sel = outfitSel[t.id] || 1;
    const opts = t.outfits.map((o, i) => `<option value="${i + 1}" ${i + 1 === sel ? 'selected' : ''}>${o}</option>`).join('');
    const label = full ? 'Contract limit reached' : (afford ? `Hire · ${d.admin ? 'free' : money(t.price)}` : 'Not enough money');
    return `<div class="tier" style="--c:${t.color}">
      <div class="tier-top"><span class="tier-name">${t.label}</span><span class="tier-price">${money(t.price)}</span></div>
      <div class="tier-desc">${t.desc}</div>
      ${srow('Health', t.health, maxH)}${srow('Armour', t.armour, maxA)}${srow('Accuracy', t.accuracy, 100)}
      <div class="tier-weapon"><i data-icon="gun"></i>${t.weapon}</div>
      <select data-outfit="${t.id}">${opts}</select>
      <button class="hire" data-hire="${t.id}" ${(!afford || full) ? 'disabled' : ''}>${label}</button>
    </div>`;
  }).join('');
  $('#shopServices').innerHTML = `Services (F9 panel):<span>Escort car <b>${money(d.services.escort)}</b></span><span>Air support <b>${money(d.services.air)}</b></span><span>Medic <b>${money(d.services.heal)}</b>/guard</span>`;
  applyIcons(shop);
}

window.addEventListener('message', (e) => {
  const msg = e.data || {};
  if (msg.type === 'open') panel.classList.remove('hidden');
  if (msg.type === 'close') panel.classList.add('hidden');
  if (msg.type === 'update') render(msg);
  if (msg.type === 'shop') {
    if (msg.open) { shop.classList.remove('hidden'); if (msg.data) renderShop(msg.data); }
    else shop.classList.add('hidden');
  }
});

// two-click confirm for buttons that end a paid contract
let armedRow = null, armedRowAt = 0;
const armedBtns = new Map();
function armButton(b, label) {
  if (armedBtns.has(b)) {
    clearTimeout(armedBtns.get(b)); armedBtns.delete(b);
    b.innerHTML = b.dataset.orig; b.classList.remove('armed');
    return true;
  }
  b.dataset.orig = b.innerHTML; b.textContent = label; b.classList.add('armed');
  armedBtns.set(b, setTimeout(() => { armedBtns.delete(b); b.innerHTML = b.dataset.orig; b.classList.remove('armed'); }, 3000));
  return false;
}

function armDismiss(b) {
  if (dismissArmed) { clearTimeout(dismissArmed); dismissArmed = null; b.textContent = 'Dismiss all'; b.classList.remove('armed'); return true; }
  b.textContent = 'Click again to confirm'; b.classList.add('armed');
  dismissArmed = setTimeout(() => { dismissArmed = null; b.textContent = 'Dismiss all'; b.classList.remove('armed'); }, 3000);
  return false;
}

document.addEventListener('click', (e) => {
  const b = e.target.closest('button');
  // hiring screen open: it owns all clicks
  if (!shop.classList.contains('hidden')) {
    if (!b) { if (!e.target.closest('#shop')) post('shopclose'); return; }
    if (e.detail === 0 && e.clientX === 0 && e.clientY === 0) { e.preventDefault(); return; }
    b.blur();
    if (b.dataset.shop === 'close') post('shopclose');
    else if (b.dataset.hire) {
      b.disabled = true; b.textContent = 'Signing contract...';
      post('hire', { tier: b.dataset.hire, outfit: outfitSel[b.dataset.hire] || 1 });
    }
    return;
  }
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
    if (!idx) return;
    const ga = b.dataset.gaction;
    const g = lastData && lastData.guards.find(x => x.index === idx);
    if ((ga === 'dismiss' || ga === 'sendhome') && g && g.contract) {
      if (b.classList.contains('x')) {
        // table ✕ is re-rendered every update, so its armed state lives in armedRow
        if (!(armedRow === idx && Date.now() - armedRowAt < 3000)) { armedRow = idx; armedRowAt = Date.now(); render(lastData); return; }
        armedRow = null;
      } else if (!armButton(b, 'Click again: contract ends, no refund')) return;
    }
    post('guard', { action: ga, index: idx });
    if (ga === 'dismiss' || ga === 'sendhome') selected = null;
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
  if (t.dataset.outfit) { outfitSel[t.dataset.outfit] = Number(t.value) || 1; return; }
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
  if (e.key === 'Escape' || e.key === 'Esc' || e.keyCode === 27) {
    e.preventDefault();
    if (!shop.classList.contains('hidden')) post('shopclose'); else post('action', { action: 'close' });
    return;
  }
  if (e.key === ' ' || e.key === 'Enter' || e.key === 'Tab' || e.key === 'Spacebar') { e.preventDefault(); if (document.activeElement && document.activeElement.blur) document.activeElement.blur(); }
}
window.addEventListener('keydown', onKey);
window.addEventListener('keyup', onKey);

// ---------- demo mode (outside FiveM): ?demo=1&tab=squad&role=citizen|admin&shop=1 ----------
// Used for store screenshots and the assets/showcase.html gallery. Never active in game.
(function demo() {
  if (inGame) return;
  const q = new URLSearchParams(location.search);
  if (!q.has('demo')) return;
  const role = q.get('role') || 'admin';
  const now = Date.now();
  const guards = [
    { index: 1, name: 'Marcus', tier: 'Professional', tierColor: '#3b82f6', rank: 'Veteran', contract: true, weapon: 'SMG', kills: 6, health: 300, maxHealth: 350, armour: 100, maxArmour: 100, distance: 0, state: 'Driving', dead: false },
    { index: 2, name: 'Viktor', tier: 'Elite', tierColor: '#8b5cf6', rank: 'Recruit', contract: true, weapon: 'Carbine Rifle', kills: 1, health: 140, maxHealth: 500, armour: 0, maxArmour: 200, distance: 6, state: 'Firing', dead: false },
    { index: 3, name: 'Rico', tier: 'Heavy Gunner', tierColor: '#ef4444', rank: 'Legend', contract: true, weapon: 'Combat MG', kills: 17, health: 500, maxHealth: 700, armour: 300, maxArmour: 300, distance: 14, state: 'Escorting', dead: false },
    { index: 4, name: 'Logan', tier: 'Rookie', tierColor: '#94a3b8', rank: 'Recruit', contract: true, weapon: 'Pistol .50', kills: 0, health: 200, maxHealth: 200, armour: 50, maxArmour: 50, distance: 3, state: 'Following', dead: false },
  ];
  const data = {
    type: 'update', admin: role === 'admin',
    agency: { name: 'Bodyguard Agency', active: 4, max: role === 'admin' ? 6 : 4, prices: { escort: 2500, air: 10000, heal: 750 } },
    max: 6, mode: 'follow', formation: 2, driveStyle: 'rushed', autoDriveBy: true, escort: true, air: false,
    driveStatus: 'Marcus → waypoint, 640 m · Escort 14 m', styleInfo: '<b>Rushed</b>: 180 km/h target, +15% top speed. Applies to chauffeur, cruise and escort.',
    log: [
      { t: now - 95000, msg: 'Viktor signed (Elite) for $15,000', kind: '' },
      { t: now - 61000, msg: 'Squad moving to position', kind: 'hot' },
      { t: now - 32000, msg: 'Attack order: 3 guard(s) engaging', kind: 'hot' },
      { t: now - 14000, msg: 'Marcus promoted to Veteran', kind: 'hot' },
      { t: now - 5000, msg: 'Target vehicle destroyed', kind: 'hot' },
    ],
    settings: { recruitModel: 'swat', recruitWeapon: 'random', escortVehicle: 'insurgent', spacing: 1.8, accuracy: 85, invincible: false, regen: true, reinforce: true, blips: true, pos: 'center', scale: 1, customOffsets: {}, seats: { '-1': 'Marcus', '0': 'Viktor', '1': 'Rico', '2': 'Logan' } },
    options: { models: [{ id: 'blackops1', label: 'Blackops' }, { id: 'swat', label: 'SWAT' }], weapons: [{ id: 'carbine', label: 'Carbine Rifle' }, { id: 'rpg', label: 'RPG' }], escortVehicles: [{ id: 'granger', label: 'Granger' }, { id: 'insurgent', label: 'Insurgent' }] },
    guards,
  };
  const shopData = {
    name: 'Bodyguard Agency', admin: false, balance: 18400, active: 3, max: 4, squad: 3, squadMax: 6,
    services: { escort: 2500, air: 10000, heal: 750 },
    tiers: [
      { id: 'rookie', label: 'Rookie', color: '#94a3b8', price: 2500, desc: "Private security. Cheap, keeps trouble at arm's length.", weapon: 'Pistol .50', health: 300, armour: 50, accuracy: 45, outfits: ['Security', 'Securoguard'] },
      { id: 'pro', label: 'Professional', color: '#3b82f6', price: 7500, desc: 'Trained close-protection officer in a sharp suit.', weapon: 'SMG', health: 450, armour: 100, accuracy: 65, outfits: ['Suit', 'Suit II'] },
      { id: 'elite', label: 'Elite', color: '#8b5cf6', price: 15000, desc: 'Ex-special forces operator. Professional, hard to put down.', weapon: 'Carbine Rifle', health: 600, armour: 200, accuracy: 80, outfits: ['Black Ops', 'Black Ops II'] },
      { id: 'heavy', label: 'Heavy Gunner', color: '#ef4444', price: 25000, desc: 'Armoured tactical unit with a light machine gun.', weapon: 'Combat MG', health: 800, armour: 200, accuracy: 70, outfits: ['SWAT'] },
    ],
  };
  document.body.style.background = q.get('bg') || 'transparent';
  if (q.get('shop') === '1') {
    window.postMessage({ type: 'shop', open: true, data: shopData }, '*');
    return;
  }
  window.postMessage({ type: 'open' }, '*');
  window.postMessage(data, '*');
  const tab = q.get('tab');
  if (tab) {
    const b = document.querySelector(`.nav[data-tab="${tab}"]`);
    if (b) b.dispatchEvent(new MouseEvent('click', { bubbles: true, clientX: 5, clientY: 5, detail: 1 }));
    if (tab === 'squad') { selected = 2; render(data); }
  }
})();
