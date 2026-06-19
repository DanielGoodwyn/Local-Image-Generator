# Daniel's Local Image Generator Walkthrough

Last verified: 2026-06-19 12:34 PDT

This is the practical local guide for **Local Image Generator** on this Mac.

HTML version: `/Users/danielgoodwyn/src/Local Image Generator/DANIEL_LOCAL_WALKTHROUGH.html`

## Current State

| Item | Value |
| --- | --- |
| Desktop app | `/Users/danielgoodwyn/Desktop/Local Image Generator.app` |
| Applications copy | `/Users/danielgoodwyn/Applications/Local Image Generator.app` |
| Backend source | `/Users/danielgoodwyn/src/Local Image Generator` |
| Internal local URL | `http://127.0.0.1:7865/` |
| Python environment | `/Users/danielgoodwyn/src/Local Image Generator/.venv-mvp` |
| Output folder | `/Users/danielgoodwyn/Pictures/Local Image Generator` |
| Model checkpoint | `/Users/danielgoodwyn/src/Local Image Generator/models/checkpoints/juggernautXL_v8Rundiffusion.safetensors` |
| Latest desktop proof image | `/Users/danielgoodwyn/Pictures/Local Image Generator/local-image-generator-proof-red-panda.png` |

## Start the App

Open this app icon:

```text
/Users/danielgoodwyn/Desktop/Local Image Generator.app
```

The app starts or reuses the local backend automatically, opens the generator in a native window, and shows saved images in the right-side gallery panel.

Preferred desktop workflow:

1. Type the prompt into the native `Prompt` field at the top of the app.
2. Type an optional deterministic filename into the native `Filename` field.
3. Click `Generate image`.
4. Watch the right-side `Saved images` panel for the new image.

The embedded advanced generator UI remains available below the native controls for settings, styles, and debugging.

Fallback/debug command:

Run this from Terminal only if you need to debug the backend directly:

```bash
cd /Users/danielgoodwyn/src/Local Image Generator
PYTHONUNBUFFERED=1 \
PYTORCH_ENABLE_MPS_FALLBACK=1 \
GRADIO_SERVER_PORT=7865 \
TOKENIZERS_PARALLELISM=false \
.venv-mvp/bin/python launch.py \
  --always-no-vram \
  --attention-split \
  --vae-in-cpu \
  --all-in-fp16 \
  --disable-in-browser
```

Then open the internal local URL only for debugging:

```text
http://127.0.0.1:7865/
```

Leave the Terminal window open while using the fallback command. Closing it stops the backend.

## Good Local Defaults

These defaults are set in `/Users/danielgoodwyn/src/Local Image Generator/config.txt`:

| Setting | Default | Why |
| --- | --- | --- |
| Advanced | On | Exposes settings and filename field immediately |
| Performance | Speed | Stable local mode |
| Image Number | 1 | Avoids batch memory spikes |
| Aspect Ratio | 640x640 | Good MVP quality without overloading memory/swap |
| Output Format | png | Best simple proof format |
| Sampling Steps | 16 | Good local quality/speed balance |
| Negative Prompt | Prefilled | Avoids text artifacts, watermarks, bad anatomy, blur |

Do not use `Quality`, `1152x896`, and `2` images on this machine unless you have plenty of free disk space and are prepared for slower runs. That combination caused the connection error shown in Chrome.

## UI Map

```text
Native top bar
  Prompt
  Filename
  Generate image

Embedded generator
  Prompt box
  Generate button

[ ] Input Image   [ ] Enhance   [x] Advanced

Settings tab
  Performance: Speed
  Aspect Ratios: 640x640
  Image Number: 1
  Output Format: png
  Output Filename: optional deterministic filename
  Negative Prompt: prefilled quality guard

Advanced tab
  Developer Debug Mode
    Forced Overwrite of Sampling Step: 16
```

## Filename Field

Use the native `Filename` field at the top of the desktop app for the normal workflow.

The embedded `Output Filename` field in the `Settings` tab is still available for direct advanced UI use.

Example:

```text
Output Filename: mountain-car
```

The app will save directly as:

```text
/Users/danielgoodwyn/Pictures/Local Image Generator/mountain-car.png
```

This is not a rename-after-generation step. The local save pipeline writes this filename deterministically.

## Latest Desktop Proof

The latest verified desktop-app proof was generated from the native `Prompt`, `Filename`, and `Generate image` controls.

Prompt:

```text
Photorealistic wildlife portrait of a red panda standing on a mossy branch, soft forest light, detailed fur, bright eyes, natural background, 85mm lens, crisp focus, high detail, realistic photography
```

Filename:

```text
local-image-generator-proof-red-panda
```

Output:

```text
/Users/danielgoodwyn/Pictures/Local Image Generator/local-image-generator-proof-red-panda.png
```

## Prompt Recipe

Use one clear subject, one setting, one lighting setup, and one camera/composition phrase.

Template:

```text
Photorealistic [subject] in [specific setting], [lighting], [camera/lens], [composition], crisp focus, high detail, natural materials, cinematic contrast
```

Good example:

```text
Photorealistic race car parked on a rain-slick mountain road at night, bright headlights cutting through mist, wet carbon fiber bodywork, cinematic moonlight rim light, low angle 85mm automotive photography, crisp focus, high detail
```

Avoid contradictions like:

```text
racecar resting on a track, headlights looking at camera
```

Better:

```text
race car parked on a track, headlights aimed toward the camera
```

## Text In Images

The local SDXL backend can make sharp images on this Mac, but exact text inside the generated image is unreliable. If you need readable lettering, generate the image first and add text later in an editor or script.

## Troubleshooting

### Chrome Shows `Connection errored out`

Likely causes:

- Too large: `1152x896` or higher
- Too many steps: `30` or `60`
- Too many images: image number `2` or more
- Too little free disk/swap space

Fix:

1. Refresh or click `Reconnect`.
2. Use `640x640`.
3. Use image number `1`.
4. Keep `Speed`.
5. Keep the 16-step overwrite.
6. Make sure the Mac has several GB free.

Check disk:

```bash
df -h /Users/danielgoodwyn/Pictures/Local Image Generator
```

### App Is Not Responding

Check whether the local backend is listening:

```bash
lsof -nP -iTCP:7865 -sTCP:LISTEN
```

If nothing is listening, quit and reopen `Local Image Generator.app`. Use the fallback command above only for debugging.

### Find Generated Images

```bash
find /Users/danielgoodwyn/Pictures/Local Image Generator -maxdepth 2 -type f -name '*.png' -print
```

## Local Code Changes

This install is not a pristine upstream checkout. Local changes include:

- `webui.py`: added `Output Filename` field and made preview disabled by default.
- `modules/async_worker.py`: carries the requested filename through generation.
- `modules/private_logger.py`: saves directly to the requested filename.
- `config.txt`: sets safe local defaults for this Mac.
- `desktop/LocalImageGeneratorApp.swift`: native macOS wrapper with prompt/filename controls, an embedded generator view, and saved-image gallery.
