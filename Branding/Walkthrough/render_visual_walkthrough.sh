#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/output"
CLIPS="$OUT/rendered_clips"
FONT="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
mkdir -p "$CLIPS"

render_still() {
  local id="$1"
  local image="$2"
  local audio="$3"
  local seconds="$4"
  local caption="$5"
  local frames=$((seconds * 30))
  local fade_start=$((seconds - 1))
  local safe_caption="${caption//:/\\:}"

  ffmpeg -y -hide_banner -loglevel error \
    -loop 1 -framerate 30 -i "$image" -i "$audio" \
    -filter_complex "[0:v]scale=1280:720:force_original_aspect_ratio=increase,crop=1280:720,zoompan=z='min(zoom+0.0006,1.07)':d=${frames}:s=1280x720:fps=30,fade=t=in:st=0:d=0.35,fade=t=out:st=${fade_start}:d=0.35,drawbox=x=0:y=568:w=1280:h=152:color=0x0B172A@0.86:t=fill,drawtext=fontfile=${FONT}:fontcolor=white:fontsize=36:x=(w-text_w)/2:y=626:text='${safe_caption}'[v];[1:a]apad=pad_dur=${seconds}[a]" \
    -map "[v]" -map "[a]" -t "$seconds" \
    -c:v libx264 -pix_fmt yuv420p -r 30 -c:a aac -b:a 192k \
    "$CLIPS/${id}.mp4"
}

render_intro() {
  local audio="$ROOT/narration/01_intro.wav"
  ffmpeg -y -hide_banner -loglevel error \
    -i "$ROOT/clips/01_intro.mp4" -i "$audio" \
    -filter_complex "[0:v]scale=1280:720,drawbox=x=0:y=568:w=1280:h=152:color=0x0B172A@0.86:t=fill,drawtext=fontfile=${FONT}:fontcolor=white:fontsize=36:x=(w-text_w)/2:y=626:text='SpeachText1.0  |  Local-first dictation'[v];[1:a]apad=pad_dur=8[a]" \
    -map "[v]" -map "[a]" -t 8 \
    -c:v libx264 -pix_fmt yuv420p -r 30 -c:a aac -b:a 192k \
    "$CLIPS/01_intro.mp4"
}

render_intro
render_still "02_install" "$ROOT/primary_desktop_anchor.png" "$ROOT/narration/02_install.wav" 8 "Install in Applications"
render_still "03_permissions" "$ROOT/primary_desktop_anchor.png" "$ROOT/narration/03_permissions.wav" 8 "Allow Microphone and Accessibility"
render_still "04_dictation" "$ROOT/primary_desktop_anchor.png" "$ROOT/narration/04_dictation.wav" 8 "Hold your shortcut and speak"
render_still "05_local_ai" "$ROOT/primary_desktop_anchor.png" "$ROOT/narration/05_local_ai.wav" 8 "Speach Intelligence stays on your Mac"
render_still "06_command_mode" "$ROOT/primary_desktop_anchor.png" "$ROOT/narration/06_command_mode.wav" 8 "Command Mode previews important actions"
render_still "07_privacy_lock" "$ROOT/privacy_lock_reference.png" "$ROOT/narration/07_privacy_lock.wav" 7 "Privacy Lock protects sensitive contexts"
render_still "08_voice_macros" "$ROOT/voice_macro_reference.png" "$ROOT/narration/08_voice_macros.wav" 7 "Voice Macros use exact phrases"
render_still "09_recovery_vault" "$ROOT/recovery_vault_reference.png" "$ROOT/narration/09_recovery_vault.wav" 7 "Recovery Vault gives you a fast undo"
render_still "10_settings" "$ROOT/primary_desktop_anchor.png" "$ROOT/narration/10_settings.wav" 7 "Choose what runs and when"
render_still "11_everyday_flow" "$ROOT/voice_macro_reference.png" "$ROOT/narration/11_everyday_flow.wav" 7 "Dictate  |  Improve  |  Automate  |  Recover"
render_still "12_close" "$ROOT/primary_desktop_anchor.png" "$ROOT/narration/12_close.wav" 7 "Ready when you are"

cat > "$OUT/concat.txt" <<EOF
file '$CLIPS/01_intro.mp4'
file '$CLIPS/02_install.mp4'
file '$CLIPS/03_permissions.mp4'
file '$CLIPS/04_dictation.mp4'
file '$CLIPS/05_local_ai.mp4'
file '$CLIPS/06_command_mode.mp4'
file '$CLIPS/07_privacy_lock.mp4'
file '$CLIPS/08_voice_macros.mp4'
file '$CLIPS/09_recovery_vault.mp4'
file '$CLIPS/10_settings.mp4'
file '$CLIPS/11_everyday_flow.mp4'
file '$CLIPS/12_close.mp4'
EOF

ffmpeg -y -hide_banner -loglevel error -f concat -safe 0 -i "$OUT/concat.txt" \
  -c:v libx264 -pix_fmt yuv420p -c:a aac -b:a 192k -movflags +faststart \
  "$OUT/SpeachText1.0-Instructional-Walkthrough.mp4"

ffprobe -v error -show_entries format=duration:stream=codec_name,width,height -of default=noprint_wrappers=1 \
  "$OUT/SpeachText1.0-Instructional-Walkthrough.mp4"
