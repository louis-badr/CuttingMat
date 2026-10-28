// devices.js - screen presets.
//
// ppi decides the real-world scale: 1 cm = ppi / 2.54 pixels, so a square of
// the grid measures 1 cm on the panel. Wallpapers are rendered at the panel's
// native resolution, so use "Fill screen" in macOS and keep the default
// resolution ("Looks like" scaling) of the display for the scale to hold.
//
// menubar is the height in native pixels that the menu bar (and the notch on
// MacBooks) hides at the top. The mat starts just below it. All values can be
// edited in the page; the Air and external display values are approximations.

const DEVICES = [
  { id: 'mbp14', name: 'MacBook Pro 14"', width: 3024, height: 1964, ppi: 254, menubar: 74 },
  { id: 'mbp16', name: 'MacBook Pro 16"', width: 3456, height: 2234, ppi: 254, menubar: 74 },
  { id: 'mba13', name: 'MacBook Air 13" (M2 and later)', width: 2560, height: 1664, ppi: 224, menubar: 64 },
  { id: 'mba15', name: 'MacBook Air 15"', width: 2880, height: 1864, ppi: 224, menubar: 62 },
  { id: 'imac24', name: 'iMac 24"', width: 4480, height: 2520, ppi: 218, menubar: 48 },
  { id: 'studio27', name: 'Studio Display 27"', width: 5120, height: 2880, ppi: 218, menubar: 48 },
  { id: 'custom', name: 'Custom', width: 2560, height: 1440, ppi: 110, menubar: 48 },
];
