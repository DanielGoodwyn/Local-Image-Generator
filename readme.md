# Local Image Generator

Native macOS wrapper for a local SDXL image-generation backend.

The normal workflow is now:

1. Open `/Users/danielgoodwyn/Desktop/Local Image Generator.app`.
2. Type a prompt in the native `Prompt` field at the top of the window.
3. Type an optional deterministic filename in the native `Filename` field.
4. Click `Generate image`.
5. Preview saved images in the right-side `Saved images` panel.

Generated images save to:

```text
/Users/danielgoodwyn/Pictures/Local Image Generator
```

## Verified Proof

Last verified: 2026-06-19 12:34 PDT

The desktop app generated this proof image from its native Prompt/Filename/Generate controls:

```text
/Users/danielgoodwyn/Pictures/Local Image Generator/local-image-generator-proof-red-panda.png
```

Prompt used:

```text
Photorealistic wildlife portrait of a red panda standing on a mossy branch, soft forest light, detailed fur, bright eyes, natural background, 85mm lens, crisp focus, high detail, realistic photography
```

## Installed App Paths

```text
/Users/danielgoodwyn/Desktop/Local Image Generator.app
/Users/danielgoodwyn/Applications/Local Image Generator.app
```

The Desktop item is a shortcut to the signed app in `~/Applications`.

## Local Defaults

The local defaults are tuned for this Mac:

| Setting | Default |
| --- | --- |
| Performance | Speed |
| Image number | 1 |
| Aspect ratio | 640x640 |
| Output format | png |
| Sampling steps | 16 |
| Backend flags | no-VRAM, split attention, VAE in CPU, fp16 |

These defaults prioritize successful local generation over maximum resolution. Higher resolution, more steps, or multiple images can work, but they are more likely to be slow or fail on this machine.

## Documentation

Detailed local walkthrough:

```text
/Users/danielgoodwyn/src/Local Image Generator/DANIEL_LOCAL_WALKTHROUGH.md
/Users/danielgoodwyn/src/Local Image Generator/DANIEL_LOCAL_WALKTHROUGH.html
```

## Development Notes

Important local changes:

- `desktop/LocalImageGeneratorApp.swift`: native macOS app, auto-starts/reuses the backend, provides native prompt/filename controls, and previews saved images.
- `webui.py`: sets the page title to `Local Image Generator`, adds `Output Filename`, hides web-only branding, and starts with safe local defaults.
- `modules/async_worker.py`: carries the requested output filename through the generation task.
- `modules/private_logger.py`: writes directly to the requested filename when provided.
- `modules/config.py`, `modules/sdxl_styles.py`, `config.txt`: local default and visible-name adjustments.

## Rebuild The Desktop App

```bash
swiftc /Users/danielgoodwyn/src/Local Image Generator/desktop/LocalImageGeneratorApp.swift \
  -o /Users/danielgoodwyn/src/Local Image Generator/desktop/build/LocalImageGenerator \
  -framework AppKit -framework WebKit
```

After copying the binary into the `.app` bundle, sign it ad hoc:

```bash
codesign --force --deep --sign - "/Users/danielgoodwyn/Applications/Local Image Generator.app"
```
