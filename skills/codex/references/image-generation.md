# Codex for Image Generation

Codex bundles an [official `imagegen` skill](https://github.com/openai/codex/blob/main/codex-rs/skills/src/assets/samples/imagegen/SKILL.md) that drives the built-in `image_gen` tool (model: **`gpt-image-2`**, [announced Oct 2025](https://community.openai.com/t/introducing-gpt-image-2-available-today-in-the-api-and-codex/1379479)). Available under both subscription auth and API-key auth. Image turns count toward usage limits at roughly 3-5× the rate of text turns.

Reach for Codex image gen when you want:

- Iteration speed without leaving the terminal
- Subscription-billed generation (no per-image API charge)
- Mockups, illustrations, infographics, banners, realistic hero imagery

Pick a different tool when:

- You need **video** or **audio** → use a dedicated media-processing workflow outside this skill set
- You need a **curated 129-prompt library** → `/hs:ai-artist`
- You need **brand-grade identity assets** → `/hs:design`

## Invocation: Use The Bundled `$imagegen` Skill

The recommended invocation pattern (per upstream docs):

```bash
codex exec --full-auto --skip-git-repo-check -C "$PWD" </dev/null \
  "Use \$imagegen skill to create a 1200x630 OG card: minimalist isometric
   developer workspace, dark theme, brand color #FF6B35, no text."
```

The literal `$imagegen` token tells Codex to load and follow its bundled skill, which handles model selection, prompt augmentation, save-path policy, and the chroma-key transparency flow correctly.

You can also just describe the image — Codex routes to `image_gen` automatically — but explicit `$imagegen` invocation gives more consistent, project-aware behavior.

## Two Modes (Upstream Definitions)

| Mode                                      | When                                                                                                                 | Auth                      |
| ----------------------------------------- | -------------------------------------------------------------------------------------------------------------------- | ------------------------- |
| **Built-in `image_gen` tool** (default)   | Normal generation/editing, simple transparency via chroma-key                                                        | Subscription OR API key   |
| **CLI fallback (`scripts/image_gen.py`)** | User explicitly asks for CLI/API path, or after user confirms true `gpt-image-1.5 --background transparent` fallback | Requires `OPENAI_API_KEY` |

**Rule (upstream)**: Never silently downgrade `gpt-image-2` → `gpt-image-1.5`. Ask the user first.

## Output Paths (Two Possibilities)

When an image must be copied into the repository, use root `.hs.json` → `artifacts.images.directory` as the default destination unless the user specifies another path.

Codex's built-in tool writes images under `$CODEX_HOME/generated_images/<session-uuid>/ig_<hash>.png` (default `CODEX_HOME=~/.codex`).

**Upstream save-path policy**: never leave a project-referenced asset only at the default `$CODEX_HOME/*` path. Move it into the workspace.

If your prompt says "Save as foo.png", Codex may ALSO use `workspace-write` to write directly to CWD — leading to duplicates. **Avoid "Save as X" phrasing**. Just describe the image and let `scripts/codex-generate-image.sh` (snapshots both locations and relocates anything new) handle it.

## Transparent Backgrounds (Chroma-Key Workflow)

`gpt-image-2` **does not support `background=transparent` natively**. Upstream's documented workflow:

### Step 1 — Generate on flat chroma-key background

Default key: `#00ff00`. Use `#ff00ff` only when the subject is green. Avoid `#0000ff` for blue subjects.

Prompt template:

```text
Create the requested subject on a perfectly flat solid #00ff00 chroma-key
background for background removal. The background must be one uniform color
with no shadows, gradients, texture, reflections, floor plane, or lighting
variation. Keep the subject fully separated from the background with crisp
edges and generous padding. Do not use #00ff00 anywhere in the subject.
No cast shadow, no contact shadow, no reflection, no watermark, and no text
unless explicitly requested.
```

### Step 2 — Strip the key with the bundled helper

```bash
python "${CODEX_HOME:-$HOME/.codex}/skills/.system/imagegen/scripts/remove_chroma_key.py" \
  --input ./assets/source.png \
  --out   ./assets/final.png \
  --auto-key border \
  --soft-matte \
  --transparent-threshold 12 \
  --opaque-threshold 220 \
  --despill
```

### Step 3 — Validate

```bash
identify -format "%[channels] %wx%h\n" ./assets/final.png   # should show 'a' for alpha
```

If a thin key-color fringe remains: retry once with `--edge-contract 1`. Only add `--edge-feather 0.25` when edges are visibly stair-stepped AND the subject is not shiny/reflective.

### When To Escalate To `gpt-image-1.5` Native Transparency

Ask the user before switching. Cases where chroma-key won't be clean:

- Hair, fur, feathers, smoke, glass, liquids
- Translucent materials, reflective objects
- Soft shadows, realistic product grounding
- Subject colors conflicting with all practical key colors

Confirmation script (verbatim from upstream):

> This likely needs true native transparency. The default built-in path uses a chroma-key background plus local removal, but true transparency requires the CLI fallback with `gpt-image-1.5` because `gpt-image-2` does not support `background=transparent`. It also requires `OPENAI_API_KEY`. Should I proceed with that CLI fallback?

Then run (only after user confirms):

```bash
codex exec -m gpt-image-1.5 \
  -c image.background=transparent \
  -c image.output_format=png \
  --full-auto -C "$PWD" </dev/null \
  "Use \$imagegen skill via CLI to ... transparent PNG"
```

## Common Asset Recipes

### Hero banner

```
Use $imagegen skill. 1920x600 hero: <subject>, cinematic lighting, shallow DoF,
palette <colors>, leave left third empty for text overlay.
```

### Icon set

```
Use $imagegen skill. Generate 6 separate icons, 256x256 each, on flat #00ff00
chroma-key background: home, search, settings, user, inbox, calendar.
Outlined 2px stroke, brand color #111827, rounded corners. No #00ff00 in subjects.
```

(Then run `remove_chroma_key.py` per file.)

### Infographic

```
Use $imagegen skill. 1080x1350 portrait infographic for "<topic>". Three vertical
sections, each with flat illustration left + short label right. Palette
#0F172A / #38BDF8 / #FBBF24.
```

### Realistic blog hero

```
Use $imagegen skill. 1600x900 photorealistic: <scene>, golden hour, 35mm lens look,
no text/watermarks/logos.
```

## Multi-Asset Requests

Upstream rule: for **distinct assets**, issue **separate `image_gen` calls** — don't use the `n` variant parameter as a substitute for separate prompts (`n` is variants of one prompt). Loop in shell:

```bash
for asset in hero icon logo banner; do
  scripts/codex-generate-image.sh "Use \$imagegen skill. <prompt for $asset>" ./assets/
done
```

## Pixel Dimensions Caveat

`gpt-image-2` **does not honor exact pixel dimensions reliably** — request the aspect ratio + intended use, then resize:

```bash
convert ig_<hash>.png -resize 256x256 final.png
```

## Avoidances (Upstream + Field)

- **DO NOT** silently switch `gpt-image-2` → `gpt-image-1.5` for transparency. Ask first.
- **DO NOT** modify `$CODEX_HOME/skills/.system/imagegen/scripts/image_gen.py` (upstream rule).
- **DO NOT** use `n` for distinct assets — only for variants of one prompt.
- **DO NOT** use `image_gen` for icons/logos that should match an existing repo SVG system — edit the SVG directly instead.
- **DO NOT** leave project-referenced assets only at `$CODEX_HOME/*` — move into the workspace.
- **DO NOT** say "Save as X.png" in prompts — causes duplicate artifacts (one in `generated_images`, one in CWD).
- **DO NOT** embed sensitive text (real customer names, NDA product names) — prompts go to OpenAI.
- **DO NOT** rely on the model rendering legible text inside the image — overlay text in HTML/SVG.
- **DO NOT** generate >5 images per single `exec` call — silent mid-batch stops observed. Loop instead.

## References

- Upstream skill: <https://github.com/openai/codex/blob/main/codex-rs/skills/src/assets/samples/imagegen/SKILL.md>
- Helper script: <https://github.com/openai/codex/blob/main/codex-rs/skills/src/assets/samples/imagegen/scripts/remove_chroma_key.py>
- Model announcement: <https://community.openai.com/t/introducing-gpt-image-2-available-today-in-the-api-and-codex/1379479>
- OpenAIDevs announcement: <https://fetch.goclaw.sh/x.com/OpenAIDevs/status/2046671238534496259>
- Community discussion: <https://www.reddit.com/r/codex/comments/1t4ezlq/chatgpt_image_20_in_codex_cli/>
