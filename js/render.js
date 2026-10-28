// render.js - one entry point: options in, finished wallpaper canvas out.

// Colour schemes: dark mat + one ink colour for every mark.
const PALETTES = [
  { id: 'navy', name: 'Navy, cream lines', matColor: '#12183b', inkColor: '#f4efdc' },
  { id: 'forest', name: 'Green, cream lines', matColor: '#123222', inkColor: '#f4efdc' },
  { id: 'navy-yellow', name: 'Navy, yellow lines', matColor: '#12183b', inkColor: '#f2c94c' },
  { id: 'forest-yellow', name: 'Green, yellow lines', matColor: '#123222', inkColor: '#f2c94c' },
];

// A random palette, optionally different from the one given (by id).
function randomPalette(exceptId) {
  const pool = PALETTES.filter((p) => p.id !== exceptId);
  return pool[Math.floor(Math.random() * pool.length)];
}

const DEFAULTS = {
  width: 3024, height: 1964, ppi: 254, menubar: 74,
  matColor: '#12183b', inkColor: '#f4efdc', bgColor: '#000000',
  title: 'CUTTING MAT', subtitle: '{cols} × {rows} CM',
  rays: true,
};

function renderWallpaper(options) {
  const o = Object.assign({}, DEFAULTS, options);
  return drawMat(o);
}
