# Wan2.2 Docker Setup and Run Script
# This script helps you build and run Wan2.2 in Docker with GPU support

Write-Host "=== Wan2.2 Docker Setup ===" -ForegroundColor Cyan
Write-Host ""

# Check if Docker is running
Write-Host "Checking Docker status..." -ForegroundColor Yellow
$dockerRunning = $false
try {
    docker version | Out-Null
    $dockerRunning = $true
    Write-Host "✓ Docker is running" -ForegroundColor Green
} catch {
    Write-Host "✗ Docker is not running" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please start Docker Desktop and try again." -ForegroundColor Yellow
    Write-Host "After Docker starts, run this script again." -ForegroundColor Yellow
    exit 1
}

# Check for NVIDIA GPU
Write-Host ""
Write-Host "Checking for NVIDIA GPU..." -ForegroundColor Yellow
$hasNvidiaGpu = $false
try {
    $nvidiaCheck = nvidia-smi 2>$null
    if ($nvidiaCheck) {
        $hasNvidiaGpu = $true
        Write-Host "✓ NVIDIA GPU detected" -ForegroundColor Green
        nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
    }
} catch {
    Write-Host "✗ NVIDIA GPU not detected or nvidia-smi not available" -ForegroundColor Red
    Write-Host ""
    Write-Host "WARNING: This application requires an NVIDIA GPU with CUDA support." -ForegroundColor Yellow
    Write-Host "Minimum requirements:" -ForegroundColor Yellow
    Write-Host "  - RTX 4090 (24GB VRAM) for TI2V-5B model" -ForegroundColor Yellow
    Write-Host "  - A100/H100 (80GB VRAM) for other models" -ForegroundColor Yellow
    Write-Host ""
    $continue = Read-Host "Continue anyway? (y/N)"
    if ($continue -ne "y") {
        exit 1
    }
}

# Create necessary directories
Write-Host ""
Write-Host "Creating directories..." -ForegroundColor Yellow
$dirs = @("models", "outputs")
foreach ($dir in $dirs) {
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
        Write-Host "✓ Created $dir directory" -ForegroundColor Green
    } else {
        Write-Host "✓ $dir directory exists" -ForegroundColor Green
    }
}

# Ask if user wants to build the image
Write-Host ""
$build = Read-Host "Do you want to build the Docker image? This may take 10-15 minutes (y/N)"
if ($build -eq "y") {
    Write-Host ""
    Write-Host "Building Docker image..." -ForegroundColor Yellow
    Write-Host "This will download ~5GB of dependencies. Please wait..." -ForegroundColor Cyan
    docker build -t wan2.2:latest .
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Docker image built successfully" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to build Docker image" -ForegroundColor Red
        exit 1
    }
}

# Check if models exist
Write-Host ""
Write-Host "Checking for model checkpoints..." -ForegroundColor Yellow
$modelsExist = Test-Path "models\Wan2.2-*"
if (!$modelsExist) {
    Write-Host "✗ No model checkpoints found in ./models directory" -ForegroundColor Red
    Write-Host ""
    Write-Host "You need to download model checkpoints before running." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To download models, run:" -ForegroundColor Cyan
    Write-Host "  pip install 'huggingface_hub[cli]'" -ForegroundColor White
    Write-Host "  huggingface-cli download Wan-AI/Wan2.2-TI2V-5B --local-dir ./models/Wan2.2-TI2V-5B" -ForegroundColor White
    Write-Host ""
    Write-Host "Available models:" -ForegroundColor Cyan
    Write-Host "  - Wan2.2-TI2V-5B (24GB VRAM minimum)" -ForegroundColor White
    Write-Host "  - Wan2.2-T2V-A14B (80GB VRAM minimum)" -ForegroundColor White
    Write-Host "  - Wan2.2-I2V-A14B (80GB VRAM minimum)" -ForegroundColor White
    Write-Host ""
    exit 0
}

Write-Host "✓ Model checkpoints found" -ForegroundColor Green

# Detect which model is available
$availableModels = Get-ChildItem -Path "models" -Directory -Filter "Wan2.2-*" | Select-Object -ExpandProperty Name
Write-Host ""
Write-Host "Available models:" -ForegroundColor Cyan
$availableModels | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }

# Ask which model to use
Write-Host ""
Write-Host "Select a model to run:" -ForegroundColor Yellow
$modelIndex = 1
$modelMap = @{}
foreach ($model in $availableModels) {
    Write-Host "  [$modelIndex] $model" -ForegroundColor White
    $modelMap[$modelIndex] = $model
    $modelIndex++
}
$selection = Read-Host "Enter number (or 'q' to quit)"
if ($selection -eq 'q') { exit 0 }

$selectedModel = $modelMap[[int]$selection]
if (!$selectedModel) {
    Write-Host "Invalid selection" -ForegroundColor Red
    exit 1
}

# Determine task based on model name
$task = "ti2v-5B"
if ($selectedModel -like "*T2V*") { $task = "t2v-A14B" }
elseif ($selectedModel -like "*I2V*") { $task = "i2v-A14B" }
elseif ($selectedModel -like "*S2V*") { $task = "s2v-14B" }
elseif ($selectedModel -like "*Animate*") { $task = "animate-14B" }

Write-Host ""
Write-Host "Selected: $selectedModel (task: $task)" -ForegroundColor Green

# Get prompt from user
Write-Host ""
$prompt = Read-Host "Enter your prompt (or press Enter for default)"
if ([string]::IsNullOrWhiteSpace($prompt)) {
    $prompt = "Two anthropomorphic cats in comfy boxing gear and bright gloves fight intensely on a spotlighted stage."
}

# Run Docker container
Write-Host ""
Write-Host "Running Wan2.2 in Docker..." -ForegroundColor Yellow
Write-Host "This may take several minutes depending on GPU..." -ForegroundColor Cyan
Write-Host ""

$cmd = @(
    "run", "--rm", "--gpus", "all",
    "-v", "$PWD/models:/app/models",
    "-v", "$PWD/outputs:/app/outputs",
    "-v", "$PWD/examples:/app/examples",
    "wan2.2:latest",
    "--task", $task,
    "--size", "1280*704",
    "--ckpt_dir", "./models/$selectedModel",
    "--offload_model", "True",
    "--convert_model_dtype",
    "--t5_cpu",
    "--prompt", $prompt
)

& docker @cmd

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✓ Video generated successfully!" -ForegroundColor Green
    Write-Host "Check the ./outputs directory for your video." -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "✗ Generation failed" -ForegroundColor Red
}
