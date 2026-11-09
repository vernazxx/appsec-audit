# appsec-audit brand assets

Neon retro theme: a shield under a magnifier with a check mark, over a
horizon grid, with CRT scanlines.

| File | Size | Use |
|---|---|---|
| `appsec-audit-icon.svg` | 512×512 (vector) | Source of truth for the icon. Root README header |
| `appsec-audit-icon-256.png`, `-128.png`, `-64.png` | as named | Avatars, docs, anywhere SVG isn't accepted |
| `../../plugins/appsec-audit/assets/appsec-audit-icon-512.png` | 512×512 | Plugin icon, set by `"icon"` in `plugin.json` (it must live inside the plugin folder, the only part that gets installed) |
| `appsec-audit-banner.svg` | 1280×640 (vector) | Source of the banner |
| `appsec-audit-banner.png` | 1280×640 | Repository banner: upload it in GitHub **Settings → General → Social preview** |

## Palette

| Role | Hex |
|---|---|
| Background, outer | `#0B0618` |
| Background, inner glow | `#2A1650` |
| Panel / badge label | `#1A0F33` |
| Cyan (shield, title) | `#3EF0FF` |
| Pink (scan line, check) | `#FF3EA5` |
| Orange (magnifier, tagline) | `#FF8A1F` |
| Lavender (secondary text) | `#B9A6E6` |

Badges in the root README use these colours via shields.io
(`labelColor=1A0F33`, value colour from the table).

## Regenerating PNGs

The PNGs are rendered from the SVGs and optimised losslessly. After editing an
SVG, from the repository root:

```bash
B=assets/brand
for n in 64 128 256; do rsvg-convert -w $n -h $n $B/appsec-audit-icon.svg -o $B/appsec-audit-icon-$n.png; done
rsvg-convert -w 512 -h 512 $B/appsec-audit-icon.svg -o plugins/appsec-audit/assets/appsec-audit-icon-512.png
rsvg-convert -w 1280 -h 640 $B/appsec-audit-banner.svg -o $B/appsec-audit-banner.png
optipng -o2 -strip all $B/*.png plugins/appsec-audit/assets/appsec-audit-icon-512.png
```

`appsec-audit-banner.svg` uses the Inter and DejaVu Sans Mono fonts; install
them before rendering, or the text falls back to other fonts. Keep the SVGs
free of scripts, event handlers and external references.
