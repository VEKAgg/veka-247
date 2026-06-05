# Stream Overlay

Place a PNG file named `overlay.png` in this directory to burn a static overlay into the stream.

## Specs

- **Format**: PNG with transparency (RGBA)
- **Resolution**: Match your stream resolution — `1280×720` for 720p30, `1920×1080` for 1080p60
- **File size**: Keep under 2 MB for fast loading on restart
- **Position**: The overlay anchors at the top-left corner (0, 0) by default

## Changing position

Edit `scripts/playout.sh` and find the line:

```
[scaled][1:v]overlay=0:0[out]
```

Common positions:
- Top-left: `overlay=0:0`
- Top-right: `overlay=W-w-10:10`
- Bottom-left: `overlay=10:H-h-10`
- Bottom-right: `overlay=W-w-10:H-h-10`

## Applying changes

Restart the stream after adding, changing, or removing the overlay:

```bash
sudo systemctl restart playout
```

## Notes

- The overlay is composited **after** the scale/letterbox filter, so it appears at its native pixel position over the normalized 720p/1080p frame
- If the overlay PNG has a transparent background, transparency is preserved in the composite
- To disable, rename or remove `overlay.png` — no config change needed, just restart
