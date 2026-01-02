# Use NVIDIA CUDA base image with Python
FROM nvidia/cuda:12.1.0-cudnn8-runtime-ubuntu22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV CUDA_HOME=/usr/local/cuda

# Install Python and system dependencies
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    git \
    wget \
    ffmpeg \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Create symbolic link for python
RUN ln -s /usr/bin/python3.10 /usr/bin/python

# Upgrade pip
RUN pip install --upgrade pip

# Set working directory
WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies (excluding flash_attn initially as it needs torch first)
RUN pip install torch>=2.4.0 torchvision>=0.19.0 torchaudio --index-url https://download.pytorch.org/whl/cu121
RUN pip install opencv-python>=4.9.0.80 diffusers>=0.31.0 "transformers>=4.49.0,<=4.51.3" \
    tokenizers>=0.20.3 accelerate>=1.1.1 tqdm "imageio[ffmpeg]" easydict ftfy \
    dashscope imageio-ffmpeg "numpy>=1.23.5,<2"

# Copy the rest of the application
COPY . .

# Create directories for models and outputs
RUN mkdir -p /app/models /app/outputs

# Expose port if needed (for future web interface)
EXPOSE 8000

# Set entrypoint
ENTRYPOINT ["python", "generate.py"]

# Default command shows help
CMD ["--help"]
