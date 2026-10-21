# Icon sources

Lucide icons (ISC licence, `LICENSE-lucide.txt`), https://github.com/lucide-icons/lucide, files from
`https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/<name>.svg`.
Downloaded 2026-10-21. `currentColor` was replaced by white (`#ffffff`) so the UI can tint them with modulate.

Used: list-checks, messages-square, image, phone, phone-missed, phone-incoming, phone-outgoing, voicemail, chevron-left, x,
play, pause, signal, wifi, battery-full, check, check-check, video.

They are rasterised at the size needed by `OOTIcons` (ui/phone/icons.gd) with Image.load_svg_from_string, so they stay
sharp. If the game is exported, add `*.svg` to the export's non-resource include filter.
