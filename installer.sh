#!/bin/bash

# ComfyUI Installation Script
# This script installs ComfyUI (Stable Diffusion) with Python 3.10 support
# Compatible with Linux, macOS, and Windows (via Git Bash/WSL)

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_color() {
    printf "${1}${2}${NC}\n"
}

print_header() {
    echo "=================================================="
    print_color $BLUE "$1"
    echo "=================================================="
}

print_success() {
    print_color $GREEN "✓ $1"
}

print_warning() {
    print_color $YELLOW " $1"
}

print_error() {
    print_color $RED "✗ $1"
}

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif [[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" ]]; then
        OS="windows"
    else
        print_error "Unsupported operating system: $OSTYPE"
        exit 1
    fi
    print_success "Detected OS: $OS"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect GPU backend and install appropriate PyTorch
detect_gpu_backend() {
    print_header "Detecting GPU Backend"
    
    if [[ $OS == "linux" ]]; then
        # Check for NVIDIA GPU - improved detection
        if command_exists nvidia-smi; then
            if nvidia-smi > /dev/null 2>&1; then
                GPU_INFO=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits 2>/dev/null | head -1)
                if [[ -n "$GPU_INFO" ]]; then
                    print_success "NVIDIA GPU detected: $GPU_INFO"
                    print_success "Installing CUDA PyTorch"
                    if [[ $INSTALL_METHOD == "poetry" ]]; then
                        # First uninstall any existing CPU version
                        poetry run pip uninstall torch torchvision torchaudio -y > /dev/null 2>&1 || true
                        poetry run pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu121
                    else
                        pip uninstall torch torchvision torchaudio -y > /dev/null 2>&1 || true
                        pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu121
                    fi
                    return 0
                fi
            fi
        fi
        
        # Check for NVIDIA GPU via lspci as fallback
        if lspci 2>/dev/null | grep -i nvidia > /dev/null 2>&1; then
            print_success "NVIDIA GPU detected via lspci, installing CUDA PyTorch"
            if [[ $INSTALL_METHOD == "poetry" ]]; then
                poetry run pip uninstall torch torchvision torchaudio -y > /dev/null 2>&1 || true
                poetry run pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu121
            else
                pip uninstall torch torchvision torchaudio -y > /dev/null 2>&1 || true
                pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu121
            fi
            return 0
        fi
        
        # Check for AMD GPU
        if command_exists rocm-smi && rocm-smi > /dev/null 2>&1; then
            print_success "AMD GPU detected, installing ROCm PyTorch"
            if [[ $INSTALL_METHOD == "poetry" ]]; then
                poetry run pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/rocm6.0
            else
                pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/rocm6.0
            fi
            return 0
        fi
        
        # Check for AMD GPU via lspci as fallback
        if lspci 2>/dev/null | grep -i amd | grep -i vga > /dev/null 2>&1; then
            print_warning "AMD GPU detected via lspci, installing ROCm PyTorch"
            if [[ $INSTALL_METHOD == "poetry" ]]; then
                poetry run pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/rocm6.0
            else
                pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/rocm6.0
            fi
            return 0
        fi
        
        # Check for Intel GPU
        if lspci 2>/dev/null | grep -i intel | grep -i vga > /dev/null 2>&1; then
            print_warning "Intel GPU detected, installing CPU PyTorch (Intel GPU support experimental)"
            if [[ $INSTALL_METHOD == "poetry" ]]; then
                poetry run pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cpu
            else
                pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cpu
            fi
            return 0
        fi
        
        # No GPU detected
        print_warning "No GPU detected or unsupported GPU, installing CPU PyTorch"
        if [[ $INSTALL_METHOD == "poetry" ]]; then
            poetry run pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cpu
        else
            pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cpu
        fi
        
    elif [[ $OS == "macos" ]]; then
        print_success "macOS detected, installing Metal-optimized PyTorch"
        if [[ $INSTALL_METHOD == "poetry" ]]; then
            poetry run pip install torch torchvision torchaudio
        else
            pip install torch torchvision torchaudio
        fi
    else
        print_warning "Windows detected, installing CPU PyTorch (adjust manually for GPU support)"
        if [[ $INSTALL_METHOD == "poetry" ]]; then
            poetry run pip install torch torchvision torchaudio
        else
            pip install torch torchvision torchaudio
        fi
    fi
}

# Install system dependencies
install_system_deps() {
    print_header "Installing System Dependencies"
    
    case $OS in
        linux)
            if command_exists pacman; then
                # Arch Linux, Artix Linux, Manjaro, EndeavourOS, etc.
                print_success "Detected Arch-based distribution (Arch/Artix/Manjaro)"
                sudo pacman -Syu --noconfirm
                sudo pacman -S --needed --noconfirm git python python-pip python-virtualenv base-devel
            elif command_exists apt-get; then
                # Debian, Ubuntu, Linux Mint, etc.
                print_success "Detected Debian-based distribution"
                sudo apt-get update
                sudo apt-get install -y git python3 python3-pip python3-venv build-essential
            elif command_exists yum; then
                # CentOS, RHEL (older)
                print_success "Detected RHEL-based distribution (yum)"
                sudo yum install -y git python3 python3-pip python3-devel gcc gcc-c++
            elif command_exists dnf; then
                # Fedora, CentOS Stream, RHEL (newer)
                print_success "Detected RHEL-based distribution (dnf)"
                sudo dnf install -y git python3 python3-pip python3-devel gcc gcc-c++
            elif command_exists zypper; then
                # openSUSE
                print_success "Detected openSUSE"
                sudo zypper install -y git python3 python3-pip python3-devel gcc gcc-c++
            elif command_exists apk; then
                # Alpine Linux
                print_success "Detected Alpine Linux"
                sudo apk add git python3 python3-dev py3-pip build-base
            else
                print_error "Unsupported Linux distribution. Please install git, python3, and build tools manually."
                exit 1
            fi
            ;;
        macos)
            if ! command_exists brew; then
                print_warning "Homebrew not found. Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            brew install git python@3.10
            ;;
        windows)
            print_warning "On Windows, please ensure you have:"
            print_warning "- Git for Windows installed"
            print_warning "- Python 3.10+ installed from python.org"
            print_warning "- Visual Studio Build Tools or Visual Studio Community"
            ;;
    esac
}

# Setup Python environment
setup_python_env() {
    print_header "Setting up Python Environment"
    
    # Check for available Python versions (prefer 3.10+ but allow 3.8+)
    if command_exists python3.10; then
        PYTHON_CMD="python3.10"
    elif command_exists python3.11; then
        PYTHON_CMD="python3.11"
    elif command_exists python3.12; then
        PYTHON_CMD="python3.12"
    elif command_exists python3.13; then
        PYTHON_CMD="python3.13"
        print_warning "Using Python 3.13 - some dependencies might have compatibility issues"
    elif command_exists python3; then
        PYTHON_CMD="python3"
        PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
        if command_exists bc && [[ $(echo "$PYTHON_VERSION >= 3.8" | bc -l) -eq 1 ]]; then
            print_success "Using Python $PYTHON_VERSION"
        elif [[ $(python3 -c "import sys; print(1 if sys.version_info >= (3, 8) else 0)") -eq 1 ]]; then
            print_success "Using Python $PYTHON_VERSION"
        else
            print_error "Python $PYTHON_VERSION is too old. Need Python 3.8+ (3.10+ recommended)"
            exit 1
        fi
    elif command_exists python; then
        PYTHON_CMD="python"
        PYTHON_VERSION=$(python --version | cut -d' ' -f2 | cut -d'.' -f1,2)
        if command_exists bc && [[ $(echo "$PYTHON_VERSION >= 3.8" | bc -l) -eq 1 ]]; then
            print_success "Using Python $PYTHON_VERSION"
        elif [[ $(python -c "import sys; print(1 if sys.version_info >= (3, 8) else 0)") -eq 1 ]]; then
            print_success "Using Python $PYTHON_VERSION"
        else
            print_error "Python $PYTHON_VERSION is too old. Need Python 3.8+ (3.10+ recommended)"
            exit 1
        fi
    else
        print_error "No compatible Python version found. Please install Python 3.8+ (3.10+ recommended)"
        exit 1
    fi
    
    print_success "Using Python command: $PYTHON_CMD"
    $PYTHON_CMD --version
}

# Install with Poetry (recommended)
install_with_poetry() {
    print_header "Installing ComfyUI with Poetry"
    
    # Install Poetry if not present
    if ! command_exists poetry; then
        print_warning "Poetry not found. Installing Poetry..."
        curl -sSL https://install.python-poetry.org | python3 -
        export PATH="$HOME/.local/bin:$PATH"
    fi
    
    # Clone ComfyUI repository
    if [ ! -d "ComfyUI" ]; then
        print_success "Cloning ComfyUI repository..."
        git clone https://github.com/comfyanonymous/ComfyUI.git
    fi
    
    cd ComfyUI
    
    # Create pyproject.toml for Poetry
    cat > pyproject.toml << 'EOF'
[tool.poetry]
name = "comfyui"
version = "0.1.0"
description = "ComfyUI - The most powerful and modular visual AI engine"
authors = ["ComfyUI Community"]
package-mode = false

[tool.poetry.dependencies]
python = "^3.8"
torch = {version = ">=2.0.0", source = "pytorch-cpu"}
torchvision = {version = ">=0.15.0", source = "pytorch-cpu"}
torchaudio = {version = ">=2.0.0", source = "pytorch-cpu"}

[tool.poetry.group.dev.dependencies]

[[tool.poetry.source]]
name = "pytorch-cpu"
url = "https://download.pytorch.org/whl/cpu"
priority = "explicit"

[[tool.poetry.source]]
name = "pytorch-cuda"
url = "https://download.pytorch.org/whl/cu121"
priority = "explicit"

[build-system]
requires = ["poetry-core"]
build-backend = "poetry.core.masonry.api"
EOF
    
    # Configure Poetry to use system Python
    poetry env use $PYTHON_CMD
    
    # Install dependencies
    poetry install
    
    # Install PyTorch with appropriate backend
    detect_gpu_backend
    
    # Verify PyTorch installation
    if [[ $INSTALL_METHOD == "poetry" ]]; then
        print_success "Verifying PyTorch installation..."
        poetry run python -c "import torch; print(f'PyTorch version: {torch.__version__}'); print(f'CUDA available: {torch.cuda.is_available()}'); print(f'CUDA version: {torch.version.cuda if torch.cuda.is_available() else \"N/A\"}')"
    fi
    
    # Install other requirements
    poetry run pip install -r requirements.txt
    
    print_success "ComfyUI installed with Poetry!"
    print_success "To run ComfyUI: cd ComfyUI && poetry run python main.py"
}

# Install with pyenv + venv
install_with_pyenv() {
    print_header "Installing ComfyUI with pyenv"
    
    # Install pyenv if not present
    if ! command_exists pyenv; then
        print_warning "pyenv not found. Installing pyenv..."
        if [[ $OS == "linux" ]] && command_exists pacman; then
            # Use AUR helper if available, otherwise manual install
            if command_exists yay; then
                yay -S pyenv
            elif command_exists paru; then
                paru -S pyenv
            else
                print_warning "Installing pyenv manually..."
                curl https://pyenv.run | bash
            fi
        else
            curl https://pyenv.run | bash
        fi
        export PATH="$HOME/.pyenv/bin:$PATH"
        eval "$(pyenv init -)"
        eval "$(pyenv virtualenv-init -)"
    fi
    
    # Install Python 3.10 or latest available
    PYTHON_VERSION="3.10.12"
    if ! pyenv versions | grep -q $PYTHON_VERSION; then
        print_success "Installing Python $PYTHON_VERSION with pyenv..."
        pyenv install $PYTHON_VERSION
    fi
    pyenv global $PYTHON_VERSION
    
    # Clone ComfyUI repository
    if [ ! -d "ComfyUI" ]; then
        print_success "Cloning ComfyUI repository..."
        git clone https://github.com/comfyanonymous/ComfyUI.git
    fi
    
    cd ComfyUI
    
    # Create virtual environment
    python -m venv venv
    source venv/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Set install method for GPU detection
    INSTALL_METHOD="pip"
    
    # Install PyTorch with appropriate backend
    detect_gpu_backend
    
    # Verify PyTorch installation for pip installs
    if [[ $INSTALL_METHOD == "pip" ]]; then
        print_success "Verifying PyTorch installation..."
        python -c "import torch; print(f'PyTorch version: {torch.__version__}'); print(f'CUDA available: {torch.cuda.is_available()}'); print(f'CUDA version: {torch.version.cuda if torch.cuda.is_available() else \"N/A\"}')"
    fi
    
    # Install other requirements
    pip install -r requirements.txt
    
    print_success "ComfyUI installed with Pyenv!"
    print_success "To run ComfyUI: cd ComfyUI && source venv/bin/activate && python main.py"
}

# Install with system Python and venv
install_with_venv() {
    print_header "Installing ComfyUI with Python Venv"
    
    # Clone ComfyUI repository
    if [ ! -d "ComfyUI" ]; then
        print_success "Cloning ComfyUI repository..."
        git clone https://github.com/comfyanonymous/ComfyUI.git
    fi
    
    cd ComfyUI
    
    # Create virtual environment with system Python
    $PYTHON_CMD -m venv venv
    source venv/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Set install method for GPU detection
    INSTALL_METHOD="pip"
    
    # Install PyTorch with appropriate backend
    detect_gpu_backend
    
    # Verify PyTorch installation for venv installs
    if [[ $INSTALL_METHOD == "venv" ]]; then
        print_success "Verifying PyTorch installation..."
        python -c "import torch; print(f'PyTorch version: {torch.__version__}'); print(f'CUDA available: {torch.cuda.is_available()}'); print(f'CUDA version: {torch.version.cuda if torch.cuda.is_available() else \"N/A\"}')"
    fi
    
    # Install other requirements
    pip install -r requirements.txt
    
    print_success "ComfyUI installed with Venv!"
    print_success "To run ComfyUI: cd ComfyUI && source venv/bin/activate && python main.py"
}

# Create model directories
setup_model_dirs() {
    print_header "Setting up Model Directories"
    
    mkdir -p models/checkpoints
    mkdir -p models/vae
    mkdir -p models/loras
    mkdir -p models/embeddings
    mkdir -p models/controlnet
    mkdir -p models/upscale_models
    mkdir -p models/vae_approx
    
    print_success "Model directories created!"
    print_warning "Remember to place your Stable Diffusion models in:"
    print_warning "Checkpoints: models/checkpoints/"
    print_warning "VAE: models/vae/"
    print_warning "LoRAs: models/loras/"
}

# Main installation function
main() {
    print_header "ComfyUI (Stable Diffusion) Installation Script"
    
    detect_os
    
    echo "Choose installation method:"
    echo "1) Poetry (Recommended)"
    echo "2) Pyenv + Venv"
    echo "3) System Python + Venv"
    echo "4) Install system dependencies only"
    
    read -p "Enter your choice (1-4): " choice
    
    case $choice in
        1)
            install_system_deps
            setup_python_env
            INSTALL_METHOD="poetry"
            install_with_poetry
            setup_model_dirs
            ;;
        2)
            install_system_deps
            INSTALL_METHOD="pyenv"
            install_with_pyenv
            setup_model_dirs
            ;;
        3)
            install_system_deps
            setup_python_env
            INSTALL_METHOD="venv"
            install_with_venv
            setup_model_dirs
            ;;
        4)
            install_system_deps
            ;;
        *)
            print_error "Invalid choice. Exiting."
            exit 1
            ;;
    esac
    
    print_header "Installation Complete!"
    print_success "ComfyUI has been installed successfully!"
    
    echo ""
    print_color $BLUE "Next steps:"
    print_warning "1. Download Stable Diffusion models (checkpoints) and place them in models/checkpoints/"
    print_warning "2. Optionally download VAE files and place them in models/vae/"
    print_warning "3. Run ComfyUI using the command shown above"
    print_warning "4. Open your browser to http://localhost:8188"
    
    echo ""
    print_color $BLUE "For GPU acceleration:"
    print_warning "NVIDIA: The script installs CUDA-enabled PyTorch"
    print_warning "AMD (Linux): Run with HSA_OVERRIDE_GFX_VERSION=10.3.0 python main.py"
    print_warning "Apple Silicon: PyTorch with Metal support is included"
    
    echo ""
    print_color $BLUE "Useful commands:"
    print_warning "Queue generation: Ctrl+Enter"
    print_warning "Load workflow: Ctrl+O"
    print_warning "Save workflow: Ctrl+S"
}

# Run main function
main "$@"
