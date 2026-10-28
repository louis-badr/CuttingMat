// draw-mat.js - flat cutting mat: black backdrop, rounded mat, one ink colour.
//
// Everything is measured in centimetres first (cm = ppi / 2.54 pixels), so
// one grid square is one real centimetre on the panel.

const FONT_STACK = '"Helvetica Neue", Helvetica, Arial, "Liberation Sans", sans-serif';
const RAY_ANGLES = [[10, 11.5], [20, 9.5], [30, 8.0], [45, 7.8], [60, 7.0], [80, 9.2]];

function makeCanvas(w, h) {
  const c = document.createElement('canvas');
  c.width = w;
  c.height = h;
  return c;
}

function hexToRgb(hex) {
  const n = parseInt(hex.replace('#', ''), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

// Where the mat and the grid go. Pure geometry, no drawing.
function computeLayout(o) {
  const W = o.width, H = o.height;
  const cm = o.ppi / 2.54;
  const margin = Math.round(0.16 * cm);
  const mx0 = margin;
  const my0 = Math.min(Math.round(o.menubar) + margin, Math.round(H * 0.4));
  const mx1 = W - margin;
  const my1 = H - margin;
  const pad = 0.62 * cm;
  const cols = Math.max(4, Math.floor((mx1 - mx0 - 2 * pad) / cm));
  const rows = Math.max(3, Math.floor((my1 - my0 - 2 * pad) / cm));
  const gx0 = Math.round(mx0 + ((mx1 - mx0) - cols * cm) / 2);
  const gy0 = Math.round(my0 + ((my1 - my0) - rows * cm) / 2);
  return {
    W, H, cm, cols, rows, mx0, my0, mx1, my1, gx0, gy0,
    gx1: Math.round(gx0 + cols * cm), gy1: Math.round(gy0 + rows * cm),
    radius: 0.4 * cm,
    x: (i) => Math.round(gx0 + i * cm),
    y: (j) => Math.round(gy0 + j * cm),
  };
}

function roundRectPath(ctx, x0, y0, x1, y1, r) {
  ctx.beginPath();
  ctx.moveTo(x0 + r, y0);
  ctx.arcTo(x1, y0, x1, y1, r);
  ctx.arcTo(x1, y1, x0, y1, r);
  ctx.arcTo(x0, y1, x0, y0, r);
  ctx.arcTo(x0, y0, x1, y0, r);
  ctx.closePath();
}

// Put a 1-px-wide line on pixel centres so it stays sharp.
function crisp(v, w) {
  return w % 2 === 1 ? Math.floor(v) + 0.5 : Math.round(v);
}

function fillTemplate(text, L) {
  return String(text || '').replace(/\{cols\}/g, L.cols).replace(/\{rows\}/g, L.rows);
}

function drawMat(o) {
  const L = computeLayout(o);
  const { W, H, cm, cols, rows, gx0, gy0, gx1, gy1 } = L;
  const canvas = makeCanvas(W, H);
  const ctx = canvas.getContext('2d');
  const MAT = o.matColor, INK = o.inkColor;

  const THIN = Math.max(1, Math.round(0.01 * cm));
  const MAJOR = Math.max(2, Math.round(0.02 * cm));
  const FRAME = Math.max(2, Math.round(0.03 * cm));
  const px = (cmSize) => Math.max(9, Math.round(cmSize * cm));

  ctx.fillStyle = o.bgColor;
  ctx.fillRect(0, 0, W, H);
  ctx.fillStyle = MAT;
  roundRectPath(ctx, L.mx0, L.my0, L.mx1, L.my1, L.radius);
  ctx.fill();

  // grid: fine, faint 1 cm lines; every 5 cm a normal, heavier line
  // (counted from the numbers' origin).
  const step = 5;
  const faint = 0.5;
  ctx.strokeStyle = INK;
  ctx.lineCap = 'butt';
  for (let i = 0; i <= cols; i++) {
    const strong = i % step === 0;
    const w = strong ? MAJOR : THIN;
    const x = crisp(L.x(i), w);
    ctx.lineWidth = w;
    ctx.globalAlpha = strong ? 1 : faint;
    ctx.beginPath(); ctx.moveTo(x, gy0); ctx.lineTo(x, gy1); ctx.stroke();
  }
  for (let j = 0; j <= rows; j++) {
    const strong = (rows - j) % step === 0;
    const w = strong ? MAJOR : THIN;
    const y = crisp(L.y(j), w);
    ctx.lineWidth = w;
    ctx.globalAlpha = strong ? 1 : faint;
    ctx.beginPath(); ctx.moveTo(gx0, y); ctx.lineTo(gx1, y); ctx.stroke();
  }
  ctx.globalAlpha = 1;

  // angle rays from the bottom-left origin
  const ox = gx0, oy = gy1;
  const labels = [];
  if (o.rays && cols >= 10 && rows >= 8) {
    ctx.save();
    ctx.beginPath(); ctx.rect(gx0, gy0, gx1 - gx0, gy1 - gy0); ctx.clip();
    ctx.lineWidth = Math.max(1, 0.015 * cm);
    for (const [a, dist] of RAY_ANGLES) {
      const t = a * Math.PI / 180;
      const ux = Math.cos(t), uy = -Math.sin(t);
      const tmax = Math.min((gx1 - ox) / ux, (gy1 - gy0) / Math.sin(t));
      ctx.beginPath(); ctx.moveTo(ox, oy); ctx.lineTo(ox + ux * tmax, oy + uy * tmax); ctx.stroke();
      const d = Math.min(dist, tmax / cm - 0.6);
      labels.push([a + '°', ox + ux * d * cm, oy + uy * d * cm]);
    }
    ctx.restore();
    ctx.globalAlpha = 1;
    if (cols > 12) labels.push(['0°', ox + 10.5 * cm, oy - 0.35 * cm]);
  }

  // info block, top-left, masks the grid behind it
  const title = fillTemplate(o.title, L), sub = fillTemplate(o.subtitle, L);
  if (title || sub) {
    const fTitle = 'bold ' + px(0.23) + 'px ' + FONT_STACK;
    const fSub = px(0.21) + 'px ' + FONT_STACK;
    ctx.font = fTitle; const wt = ctx.measureText(title).width;
    ctx.font = fSub; const ws = ctx.measureText(sub).width;
    const cells = Math.min(cols - 1, Math.max(4, Math.ceil((Math.max(wt, ws) + 0.56 * cm) / cm)));
    const bx1 = L.x(cells), by1 = L.y(1);
    ctx.fillStyle = MAT;
    ctx.fillRect(gx0 + 3, gy0 + 3, bx1 - gx0 - 6, by1 - gy0 - 6);
    ctx.fillStyle = INK;
    ctx.textAlign = 'left'; ctx.textBaseline = 'middle';
    const tx = gx0 + 0.28 * cm;
    if (title && sub) {
      ctx.font = fTitle; ctx.fillText(title, tx, gy0 + 0.34 * cm);
      ctx.font = fSub; ctx.fillText(sub, tx, gy0 + 0.68 * cm);
    } else {
      ctx.font = title ? fTitle : fSub;
      ctx.fillText(title || sub, tx, gy0 + 0.5 * cm);
    }
  }

  // frame
  ctx.strokeStyle = INK;
  ctx.lineWidth = FRAME;
  ctx.strokeRect(gx0 + (FRAME % 2 ? 0.5 : 0), gy0 + (FRAME % 2 ? 0.5 : 0), gx1 - gx0, gy1 - gy0);

  // small arc at the origin
  ctx.beginPath();
  ctx.arc(ox, oy, 0.55 * cm, -Math.PI / 2, 0);
  ctx.stroke();

  // angle labels on a patch of mat colour
  ctx.font = px(0.22) + 'px ' + FONT_STACK;
  ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  const pad = 0.06 * cm;
  for (const [text, x, y] of labels) {
    const tw = ctx.measureText(text).width, th = px(0.22);
    ctx.fillStyle = MAT;
    ctx.fillRect(x - tw / 2 - pad, y - th / 2 - pad, tw + 2 * pad, th + 2 * pad);
    ctx.fillStyle = INK;
    ctx.fillText(text, x, y);
  }

  // numbers on the four edges, "CM" in the corner
  const bandx = gx0 - L.mx0, bandy = gy0 - L.my0;
  ctx.fillStyle = INK;
  ctx.font = px(0.23) + 'px ' + FONT_STACK;
  for (let i = 0; i <= cols; i++) {
    const x = L.x(i);
    if (i > 0) ctx.fillText(String(i), x, gy0 - bandy / 2);
    ctx.fillText(String(i), x, gy1 + (L.my1 - gy1) / 2);
  }
  for (let j = 0; j <= rows; j++) {
    const y = gy1 - Math.round(j * cm);
    ctx.fillText(String(j), gx0 - bandx / 2, y);
    ctx.fillText(String(j), gx1 + (L.mx1 - gx1) / 2, y);
  }
  ctx.font = 'bold ' + px(0.23) + 'px ' + FONT_STACK;
  ctx.fillText('CM', gx0 - bandx / 2, gy0 - bandy / 2);

  return { canvas, layout: L };
}
