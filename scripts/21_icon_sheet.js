// Builds sheet.svg (768x512, 6x4 cells of 128 px) from the same SVG art as the Figma "Icons" page, plus cells.txt for
// Config.Icons.Cells. `node scripts/21_icon_sheet.js`, then rasterise sheet.svg at 1x (a browser canvas drawImage +
// toBlob works; no SVG tool is installed) to textures/ui/icons_v2.png and upload it.
const fs = require('fs');
const INK = '#14112b';
const G = (inner) => `<g stroke="${INK}" stroke-width="3" stroke-linejoin="round" stroke-linecap="round">${inner}</g>`;
const aura = (c = '#ffd23f') => { const pts = []; for (let i = 0; i < 24; i++) { const r = i % 2 ? 22 : 31, a = i * Math.PI / 12; pts.push((32 + r * Math.cos(a)).toFixed(1) + ',' + (32 + r * Math.sin(a)).toFixed(1)); } return `<polygon points="${pts.join(' ')}" fill="${c}" stroke="none" opacity="0.55"/>`; };
const sword = (blade = '#3a3550', edge = '#ff3b4e', w = 10) => `<g transform="rotate(45 32 32)"><path d="M${32 - w / 2} 42 V12 L32 3 L${32 + w / 2} 12 V42 Z" fill="${blade}"/><path d="M32 6 L${32 + w / 2 - 1.5} 12 V42 H32 Z" fill="${edge}" stroke="none"/><path d="M${32 - w / 2} 42 V12 L32 3 L${32 + w / 2} 12 V42 Z" fill="none"/><rect x="19" y="41" width="26" height="6" rx="3" fill="#ffd23f"/><rect x="29" y="47" width="6" height="10" fill="#a0643c"/><circle cx="32" cy="59" r="3.5" fill="#ff3b4e"/></g>`;
const fireball = (cx, cy, r) => `<path d="M${cx + r * 0.5} ${cy - r * 0.9} L${cx + r * 1.9} ${cy - r * 2.1} L${cx + r * 1.5} ${cy - r * 0.9} L${cx + r * 2.1} ${cy - r * 1.1} L${cx + r * 0.95} ${cy + r * 0.1} Z" fill="#ffd23f"/><circle cx="${cx}" cy="${cy}" r="${r}" fill="#ff9a1f"/><circle cx="${cx - r * 0.15}" cy="${cy + r * 0.15}" r="${r * 0.5}" fill="#ffd23f" stroke="none"/>`;
const flames = (R, c) => [0, 90, 180, 270].map(d => { const t = 32 - R - 11; return `<path d="M32 ${t} C37 ${t + 6} 38 ${t + 9} 32 ${t + 13} C26 ${t + 9} 27 ${t + 6} 32 ${t} Z" fill="${c}" transform="rotate(${d} 32 32)"/>`; }).join('');
const ring = (outer, inner2) => `<circle cx="32" cy="32" r="17" stroke-width="11"/><circle cx="32" cy="32" r="17" stroke="${outer}" stroke-width="5"/>${inner2 ? `<circle cx="32" cy="32" r="8" stroke-width="7"/><circle cx="32" cy="32" r="8" stroke="${inner2}" stroke-width="3"/>` : ''}${flames(17, '#ffd23f')}`;
const axe = (rot, s = 1, dx = 0) => `<g transform="translate(${dx} 0) rotate(${rot} 32 32) translate(${32 - 32 * s} ${32 - 32 * s}) scale(${s})"><rect x="29.5" y="8" width="5" height="50" rx="2.5" fill="#a0643c"/><path d="M33 7 C50 2 61 17 57 35 C49 29 41 28 33 30 Z" fill="#c9d3e8"/><path d="M38 11 C48 9 55 17 55 26" stroke="#ffffff" stroke-width="2.2"/><rect x="25" y="11" width="6" height="13" rx="2" fill="#8a93a6"/></g>`;
const rock = (x, y, s, c = '#9aa0b5') => `<path d="M${x - 6 * s} ${y + 1 * s} L${x - 3 * s} ${y - 5 * s} L${x + 4 * s} ${y - 5 * s} L${x + 7 * s} ${y} L${x + 3 * s} ${y + 5 * s} L${x - 4 * s} ${y + 5 * s} Z" fill="${c}"/><path d="M${x - 2 * s} ${y - 3 * s} L${x + 3 * s} ${y - 3 * s}" stroke="#ffffff" stroke-width="2"/>`;
const orbit = (c = INK) => `<ellipse cx="32" cy="34" rx="26" ry="14" stroke="${c}" stroke-width="2.5" stroke-dasharray="4 5"/>`;
const bolt = (x, y, s = 1, c = '#ffd23f') => `<path d="M${x + 2 * s} ${y} L${x - 6 * s} ${y + 12 * s} H${x} L${x - 3 * s} ${y + 22 * s} L${x + 8 * s} ${y + 8 * s} H${x + 2 * s} L${x + 6 * s} ${y} Z" fill="${c}"/>`;
const totem = (body = '#a0643c', eye = '#20c9e6') => `<path d="M20 26 L32 18 L44 26 Z" fill="#ff3b4e"/><rect x="21" y="26" width="22" height="32" rx="3" fill="${body}"/><rect x="25" y="32" width="5" height="5" fill="${eye}"/><rect x="34" y="32" width="5" height="5" fill="${eye}"/><rect x="26" y="44" width="12" height="5" rx="2" fill="${INK}"/>`;
const tome = (c, dark, emblem) => `<rect x="12" y="6" width="42" height="52" rx="5" fill="${c}"/><rect x="16" y="52" width="38" height="7" rx="2" fill="#ffffff"/><rect x="12" y="6" width="9" height="52" rx="3" fill="${dark}"/><circle cx="37" cy="29" r="13" fill="#ffffff"/>${emblem}`;
const E = {
  might: `<path d="M37 19 L46 29 H41 V38 H33 V29 H28 Z" fill="#ff3b4e"/>`,
  area: `<circle cx="37" cy="29" r="8" stroke-dasharray="3 3"/><circle cx="37" cy="29" r="3.5" fill="#3ddc5a"/>`,
  haste: `<circle cx="37" cy="29" r="8" fill="#3d8bff"/><path d="M37 24 V29 L41 31" stroke="#ffffff" stroke-width="2.5"/>`,
  magnet: `<path d="M30 21 V30 A7 7 0 0 0 44 30 V21 H40 V30 A3 3 0 0 1 34 30 V21 Z" fill="#ff3b4e"/><rect x="30" y="21" width="4" height="4" fill="#ffffff"/><rect x="40" y="21" width="4" height="4" fill="#ffffff"/>`,
  force: `<polygon points="37,18 40,25 47,23 43,29 48,34 41,34 39,41 35,35 28,38 31,31 26,26 33,25" fill="#ff9a1f"/>`,
  duration: `<path d="M31 20 H43 L37 29 L43 38 H31 L37 29 Z" fill="#ffd23f"/>`,
  projectile: `<path d="M27 25 H40 M36 21 L41 25 L36 29 M30 33 H43 M39 29 L44 33 L39 37" stroke-width="2.8"/>`,
  speed: `<path d="M29 21 L37 29 L29 37 M36 21 L44 29 L36 37" stroke="#3d8bff" stroke-width="4"/>`,
  luck: `<g fill="#3ddc5a"><circle cx="33.5" cy="25.5" r="4.5"/><circle cx="40.5" cy="25.5" r="4.5"/><circle cx="33.5" cy="32.5" r="4.5"/><circle cx="40.5" cy="32.5" r="4.5"/></g><path d="M37 29 L41 39" stroke-width="2.5"/>`,
};
const ring6 = [0, 60, 120, 180, 240, 300].map(d => { const a = d * Math.PI / 180; return rock(32 + 26 * Math.cos(a), 34 + 14 * Math.sin(a), 1.15, '#7fe3f2'); }).join('');
const art = {
  sword: sword(),
  fire: fireball(24, 40, 15),
  ring: ring('#ff9a1f'),
  axe: axe(-20) + `<path d="M6 44 A28 28 0 0 0 19 58" stroke-width="2.5"/><path d="M9 52 L6 44 L13 47" stroke-width="2.5"/>`,
  rocks: orbit() + `<circle cx="32" cy="34" r="5" fill="#3ddc5a"/>` + rock(11, 34, 1.5) + rock(46, 19, 1.5) + rock(44, 49, 1.5),
  totem: totem() + bolt(46, 2, 0.9),
  might: tome('#ffd23f', '#e0a800', E.might),
  area: tome('#3ddc5a', '#1fa83c', E.area),
  haste: tome('#3d8bff', '#2563d9', E.haste),
  magnet: tome('#ff6fae', '#e0458a', E.magnet),
  force: tome('#ff9a1f', '#e07800', E.force),
  duration: tome('#20c9e6', '#119cb5', E.duration),
  projectile: tome('#f5a623', '#c98000', E.projectile),
  speed: tome('#5ec8ff', '#2fa0e0', E.speed),
  luck: tome('#a259ff', '#7c3ae0', E.luck),
  skull: `<path d="M32 6C19 6 11 15 11 26c0 7 3.5 12 8.5 14.5V52h25V40.5C49.5 38 53 33 53 26 53 15 45 6 32 6z" fill="#ffffff"/><circle cx="24" cy="27" r="5" fill="${INK}"/><circle cx="40" cy="27" r="5" fill="${INK}"/><path d="M28 46 V52 M36 46 V52"/>`,
  gem: `<path d="M32 6 L54 26 L32 58 L10 26 Z" fill="#20c9e6"/><path d="M10 26 H54 M32 6 L24 26 L32 58 L40 26 Z"/><path d="M20 22 L28 14" stroke="#ffffff" stroke-width="3"/>`,
  heart: `<path d="M32 56 S8 42 8 24 A12 12 0 0 1 32 16 A12 12 0 0 1 56 24 C56 42 32 56 32 56 Z" fill="#ff3b4e"/><path d="M17 22 A6 6 0 0 1 24 17" stroke="#ffffff" stroke-width="3"/>`,
  evo_sword: aura('#ff3b4e') + sword('#ff3b4e', '#14112b', 14),
  evo_fire: aura() + fireball(18, 46, 9) + fireball(30, 32, 9) + fireball(42, 48, 9),
  evo_ring: aura() + ring('#ff3b4e', '#ffd23f'),
  evo_axe: aura('#20c9e6') + axe(-30, 0.78, -6) + axe(30, 0.78, 6),
  evo_rocks: aura('#20c9e6') + orbit('#119cb5') + `<circle cx="32" cy="34" r="5" fill="#3ddc5a"/>` + ring6,
  evo_totem: aura('#a259ff') + totem('#7c3ae0', '#ffd23f') + bolt(12, 2, 0.8) + bolt(52, 2, 0.8),
};
const order = [['sword', 'fire', 'ring', 'axe', 'rocks', 'totem'], ['might', 'area', 'haste', 'magnet', 'force', 'duration'], ['projectile', 'speed', 'luck', 'skull', 'gem', 'heart'], ['evo_sword', 'evo_fire', 'evo_ring', 'evo_axe', 'evo_rocks', 'evo_totem']];
let body = '';
const cells = [];
order.forEach((row, r) => row.forEach((k, c) => {
  body += `<svg x="${c * 128}" y="${r * 128}" width="128" height="128" viewBox="0 0 64 64" fill="none">${G(art[k])}</svg>`;
  cells.push(`\t\t${k} = { ${c * 128}, ${r * 128} },`);
}));
fs.writeFileSync(__dirname + '/sheet.svg', `<svg xmlns="http://www.w3.org/2000/svg" width="768" height="512" viewBox="0 0 768 512">${body}</svg>`);
fs.writeFileSync(__dirname + '/cells.txt', cells.join('\n') + '\n');
console.log('ok', cells.length);
