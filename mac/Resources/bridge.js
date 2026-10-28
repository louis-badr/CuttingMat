// bridge.js - the two functions the native app calls inside its hidden web view.
// The drawing code is the same as the website's (js/devices.js, draw-mat.js, render.js).

function cmwPalettes() {
  return JSON.stringify(PALETTES.map((p) => ({ id: p.id, name: p.name })));
}

// info: one display as described by the app (pixel size, physical size in mm,
// scale, menu bar height in pixels). Returns JSON with the PNG as base64.
function cmwRender(info, paletteId) {
  const w = info.pixelWidth, h = info.pixelHeight;
  const preset = DEVICES.find((p) => p.id !== 'custom' && p.width === w && p.height === h);
  let ppi = preset ? preset.ppi : (info.widthMM > 0 ? w / (info.widthMM / 25.4) : 0);
  if (!ppi || ppi < 60 || ppi > 400) ppi = 110;                    // unreliable: assume a typical monitor
  const menubar = info.menuBarPx > 0 ? info.menuBarPx : (preset ? preset.menubar : Math.round(24 * (info.scale || 1)));
  const pal = PALETTES.find((p) => p.id === paletteId) || PALETTES[0];
  const opts = {
    width: w, height: h,
    ppi: Math.round(ppi * 10) / 10, menubar: Math.round(menubar),
    matColor: pal.matColor, inkColor: pal.inkColor,
  };
  const { canvas, layout } = renderWallpaper(opts);
  return JSON.stringify({
    png: canvas.toDataURL('image/png').split(',')[1],
    cols: layout.cols, rows: layout.rows, ppi: opts.ppi, menubar: opts.menubar, width: w, height: h,
  });
}
