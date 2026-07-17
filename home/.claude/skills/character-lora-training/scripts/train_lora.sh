#!/usr/bin/env bash
# Character LoRA training driver for musubi-tuner on albedo (Windows, RTX 5080 16GB).
# Trains a Krea-2-Raw LoRA from a character dataset; result is used on Krea2 Turbo.
#
# Usage:
#   train_lora.sh stage  <slug> [steps]   # write dataset TOML + train bat on albedo (default 4000 steps)
#   train_lora.sh cache  <slug>           # cache latents + text-encoder outputs (run after dataset changes)
#   train_lora.sh train  <slug>           # free ComfyUI VRAM and launch training (RUN VIA Bash run_in_background)
#   train_lora.sh status <slug>           # tail the training log + list checkpoints
#   train_lora.sh fetch  <slug> [file]    # copy a finished .safetensors into the ComfyUI loras dir
#
# Prereqs (one-time, already done on albedo):
#   F:\musubi-tuner            musubi-tuner checkout, uv env synced with --extra cu128
#   D:\musubi-models\raw.safetensors                  Krea-2-Raw bf16 (train base; infer on turbo)
#   D:\musubi-models\text_encoders\qwen3vl_4b_bf16.safetensors
# Dataset goes in F:\musubi-tuner\dataset\<slug>\  (images + same-name .txt captions).
set -euo pipefail

HOST=albedo
SSH="ssh -o BatchMode=yes -o ConnectTimeout=10"
MT='F:\musubi-tuner'
UV='C:\Users\Garulf\AppData\Local\Programs\Python\Python311\Scripts\uv.exe'
VAE='F:\Stable Diffusion\models\vae\qwen_image_vae.safetensors'
DIT='D:\musubi-models\raw.safetensors'
TE='D:\musubi-models\text_encoders\qwen3vl_4b_bf16.safetensors'
LORAS='F:\Stable Diffusion\models\loras'
COMFY_URL="${COMFYUI_URL:-http://10.0.0.80:8188}"

cmd=${1:?usage: train_lora.sh stage|cache|train|status|fetch <slug> [arg]}
slug=${2:?character slug required}
toml="configs/${slug}_512.toml"
bat="train_${slug}.bat"
log="train_${slug}.log"

case "$cmd" in
stage)
  steps=${3:-4000}
  tmp=$(mktemp -d)
  cat > "$tmp/${slug}_512.toml" <<EOF
[general]
resolution = [512, 512]
caption_extension = ".txt"
batch_size = 1
enable_bucket = true
bucket_no_upscale = false

[[datasets]]
image_directory = "F:/musubi-tuner/dataset/${slug}"
cache_directory = "F:/musubi-tuner/work/cache_512_${slug}"
num_repeats = 1
EOF
  cat > "$tmp/$bat" <<EOF
@echo off
cd /d F:\\musubi-tuner
set PYTHONUTF8=1
$UV run --extra cu128 accelerate launch --num_cpu_threads_per_process 1 --mixed_precision bf16 src/musubi_tuner/krea2_train_network.py --dit $DIT --vae "$VAE" --dataset_config $toml --sdpa --mixed_precision bf16 --timestep_sampling shift --weighting_scheme none --discrete_flow_shift 2.5 --optimizer_type adamw8bit --learning_rate 1e-4 --gradient_checkpointing --gradient_checkpointing_cpu_offload --max_data_loader_n_workers 2 --persistent_data_loader_workers --network_module networks.lora_krea2 --network_dim 32 --network_alpha 32 --fp8_base --fp8_scaled --blocks_to_swap 26 --block_swap_h2d_only --block_swap_ring_size 1 --split_attn --max_train_steps $steps --save_every_n_steps 500 --save_state --save_last_n_steps_state 500 --seed 42 --output_dir outputs/${slug} --output_name ${slug}_rank32 > F:\\musubi-tuner\\$log 2>&1
echo TRAINING-EXIT-%ERRORLEVEL% >> F:\\musubi-tuner\\$log
EOF
  $SSH $HOST "mkdir \"$MT\\dataset\\${slug}\" 2>nul & mkdir \"$MT\\configs\" 2>nul & echo ok" >/dev/null
  scp -o BatchMode=yes -q "$tmp/${slug}_512.toml" "$HOST:F:/musubi-tuner/configs/"
  scp -o BatchMode=yes -q "$tmp/$bat" "$HOST:F:/musubi-tuner/"
  rm -rf "$tmp"
  echo "staged: $MT\\$toml + $MT\\$bat ($steps steps)"
  echo "next: put images+captions in $MT\\dataset\\${slug}\\ then run: train_lora.sh cache $slug"
  ;;
cache)
  $SSH $HOST "cd /d $MT && set PYTHONUTF8=1&& $UV run --extra cu128 python src/musubi_tuner/krea2_cache_latents.py --dataset_config $toml --vae \"$VAE\" --batch_size 1 --skip_existing" 2>&1 | tail -3
  $SSH $HOST "cd /d $MT && set PYTHONUTF8=1&& $UV run --extra cu128 python src/musubi_tuner/krea2_cache_text_encoder_outputs.py --dataset_config $toml --text_encoder $TE --batch_size 1 --skip_existing" 2>&1 | tail -3
  ;;
train)
  # Free ComfyUI VRAM first — a trainer that initializes while ComfyUI holds VRAM gets
  # demoted to shared memory and stays ~2.4x slow even after VRAM frees.
  curl -s -m 10 -X POST "$COMFY_URL/free" -H "Content-Type: application/json" \
    -d '{"unload_models":true,"free_memory":true}' >/dev/null || true
  sleep 5
  # Persistent ssh: the remote cmd.exe survives ssh-client death; Start-Process/schtasks do NOT work.
  exec ssh -o BatchMode=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=20 $HOST \
    "$MT\\$bat & echo BAT-EXIT"
  ;;
status)
  $SSH $HOST "powershell -Command \"Get-Content $MT\\$log -Tail 3 -ErrorAction SilentlyContinue; dir $MT\\outputs\\${slug} 2>nul | Out-String -Width 110\""
  ;;
fetch)
  file=${3:-${slug}_rank32.safetensors}
  $SSH $HOST "copy /y \"$MT\\outputs\\${slug}\\$file\" \"$LORAS\\$file\" && echo installed: $file"
  ;;
*)
  echo "unknown command: $cmd" >&2; exit 2 ;;
esac
