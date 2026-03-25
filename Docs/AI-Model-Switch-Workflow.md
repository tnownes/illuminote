# AI Model Switch Workflow

This project now uses a build-time model copy step so we can switch AI model bundles without Xcode resource collisions.

## How It Works

- Model folders stay in: `IlluminoteSceneDemo/Resources/`
- Build setting `AI_PRIMARY_MODEL_DIR` selects which model is bundled.
- Optional fallback model can be bundled with:
  - `AI_INCLUDE_FALLBACK_MODEL = YES`
  - `AI_FALLBACK_MODEL_DIR = <folder name>`
- A build script copies selected model folders into the app bundle under their own directory names.

## Default Configuration

- `AI_PRIMARY_MODEL_DIR = Qwen3.5-2B-4bit-OptiQ`
- `AI_INCLUDE_FALLBACK_MODEL = NO`
- `AI_FALLBACK_MODEL_DIR = Qwen3-1.7B-4bit`

## Switch Models (Xcode)

1. Open target `IlluminoteSceneDemo`.
2. Go to **Build Settings**.
3. Search for:
   - `AI_PRIMARY_MODEL_DIR`
   - `AI_INCLUDE_FALLBACK_MODEL`
   - `AI_FALLBACK_MODEL_DIR`
4. Set `AI_PRIMARY_MODEL_DIR` to one of your local model folder names in `Resources`.
5. Clean build folder and build again.

## Example Values

- 2B primary:
  - `AI_PRIMARY_MODEL_DIR = Qwen3.5-2B-4bit-OptiQ`
  - `AI_INCLUDE_FALLBACK_MODEL = NO`

- 4B primary with 2B fallback:
  - `AI_PRIMARY_MODEL_DIR = Qwen3.5-4B-OptiQ-4bit`
  - `AI_INCLUDE_FALLBACK_MODEL = YES`
  - `AI_FALLBACK_MODEL_DIR = Qwen3.5-2B-4bit-OptiQ`

## Notes

- Keep only real model files (not Git LFS pointers).  
- The build script removes stale known model folders from the app bundle before copying the active selection.
- This avoids duplicate output errors like:
  - `Multiple commands produce ... config.json`
  - `Multiple commands produce ... model.safetensors`
