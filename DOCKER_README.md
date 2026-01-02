# Running Wan2.2 with Docker

This guide explains how to run Wan2.2 using Docker with GPU support.

## Prerequisites

1. **NVIDIA GPU** with CUDA support (minimum 24GB VRAM for TI2V-5B, 80GB+ for other models)
2. **NVIDIA Docker Runtime** installed
3. **Docker** and **Docker Compose** installed

### Install NVIDIA Docker Runtime

```bash
# For Ubuntu/Debian
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list

sudo apt-get update
sudo apt-get install -y nvidia-docker2
sudo systemctl restart docker
```

For Windows with WSL2, install Docker Desktop and enable WSL2 integration with GPU support.

## Quick Start

### 1. Build the Docker Image

```bash
docker build -t wan2.2:latest .
```

Or using Docker Compose:

```bash
docker-compose build
```

### 2. Download Model Checkpoints

Before running, download the model checkpoints to the `./models` directory:

```bash
# Create models directory
mkdir -p models

# Download using huggingface-cli (install if needed: pip install "huggingface_hub[cli]")
huggingface-cli download Wan-AI/Wan2.2-TI2V-5B --local-dir ./models/Wan2.2-TI2V-5B
```

Available models:
- `Wan2.2-TI2V-5B` (24GB VRAM) - Text/Image to Video
- `Wan2.2-T2V-A14B` (80GB VRAM) - Text to Video
- `Wan2.2-I2V-A14B` (80GB VRAM) - Image to Video
- `Wan2.2-S2V-14B` (80GB VRAM) - Speech to Video
- `Wan2.2-Animate-14B` (80GB VRAM) - Character Animation

### 3. Run the Container

#### Using Docker Run

**Text-to-Video (TI2V-5B):**
```bash
docker run --gpus all -v $(pwd)/models:/app/models -v $(pwd)/outputs:/app/outputs \
  wan2.2:latest \
  --task ti2v-5B \
  --size 1280*704 \
  --ckpt_dir ./models/Wan2.2-TI2V-5B \
  --offload_model True \
  --convert_model_dtype \
  --t5_cpu \
  --prompt "Two anthropomorphic cats in comfy boxing gear and bright gloves fight intensely on a spotlighted stage"
```

**Image-to-Video (TI2V-5B):**
```bash
docker run --gpus all -v $(pwd)/models:/app/models -v $(pwd)/outputs:/app/outputs -v $(pwd)/examples:/app/examples \
  wan2.2:latest \
  --task ti2v-5B \
  --size 1280*704 \
  --ckpt_dir ./models/Wan2.2-TI2V-5B \
  --offload_model True \
  --convert_model_dtype \
  --t5_cpu \
  --image examples/i2v_input.JPG \
  --prompt "Summer beach vacation style, a white cat wearing sunglasses sits on a surfboard"
```

#### Using Docker Compose

Edit `docker-compose.yml` to uncomment and modify the command section, then run:

```bash
docker-compose run --rm wan2.2
```

### 4. Check Outputs

Generated videos will be saved in the `./outputs` directory on your host machine.

## GPU Requirements

- **Minimum:** NVIDIA GPU with 24GB VRAM (RTX 4090) for TI2V-5B model
- **Recommended:** NVIDIA GPU with 80GB VRAM (A100/H100) for other models
- CUDA 12.1 or compatible

## Memory Optimization

For limited GPU memory, use these flags:
- `--offload_model True` - Offload models to CPU between passes
- `--convert_model_dtype` - Use mixed precision
- `--t5_cpu` - Keep T5 encoder on CPU

## Troubleshooting

### No GPU detected
```bash
# Check if NVIDIA runtime is working
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi
```

### Out of Memory
- Try smaller resolution: `--size 704*704`
- Enable all memory optimization flags
- Use the TI2V-5B model instead of larger models

### Permission Issues (Linux)
```bash
sudo chown -R $USER:$USER ./models ./outputs
```

## Multi-GPU Setup

For multi-GPU inference:

```bash
docker run --gpus all -v $(pwd)/models:/app/models -v $(pwd)/outputs:/app/outputs \
  wan2.2:latest \
  bash -c "torchrun --nproc_per_node=2 generate.py --task ti2v-5B --dit_fsdp --t5_fsdp --ulysses_size 2 --ckpt_dir ./models/Wan2.2-TI2V-5B --prompt 'Your prompt here'"
```

## Interactive Mode

Run container in interactive mode for debugging:

```bash
docker run --gpus all -it -v $(pwd)/models:/app/models -v $(pwd)/outputs:/app/outputs \
  wan2.2:latest bash
```

Then run commands inside the container:
```bash
python generate.py --help
```

## Notes

- First run will take time to load models into GPU memory
- Model checkpoints are NOT included in the Docker image (too large)
- Always mount the models directory as a volume
- Generated videos use significant disk space
