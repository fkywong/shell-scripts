Filename
===
compose-icon.swift

Author
===
Felix Wong

Description
===
Draws an emoji, or a small image, over the bottom-right corner of a base image and centers both on a square PNG with a transparent background. Made for app icons, e.g. a logo with a badge emoji or a smaller icon in its corner.

macOS only: it uses AppKit and the system emoji font, so nothing needs installing.

Usage
===
`compose-icon.swift BASE_IMAGE OUT_PNG [OVERLAY] [SIZE] [SHIFT] [MARGIN]`

BASE\_IMAGE

* Any image macOS can open, including SVG. It's fitted into a 224px box.

OUT\_PNG

* Output path. Existing files are overwritten.

OVERLAY (default 🔐)

* An emoji, or the path to an image file

SIZE (default 136)

* Emoji size in points, or the overlay image's side in pixels

SHIFT (default 32)

* How far to move the overlay right, in pixels

MARGIN (default 8)

* Transparent margin around the drawn content, in pixels

Notes
===

* The canvas is cropped to what was actually drawn, so its size depends on the inputs.
* Emoji glyphs and overlay images belong to their owners; check their licences before publishing an icon made with them.
