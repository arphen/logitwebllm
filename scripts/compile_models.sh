#!/bin/bash
# Compile models for WebLLM with prefill_all_logits support
# 
# Prerequisites:
# 1. Install mlc-llm: pip install mlc-llm-nightly-cu122 mlc-ai-nightly-cu122 (or appropriate variant)
# 2. Login to HuggingFace: huggingface-cli login (required for gated models like Gemma)
# 3. Build the minimal WASM runtime: cd mlc-llm/web && make minimal

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
MODELS_DIR="$ROOT_DIR/models"
MLC_LLM_DIR="$ROOT_DIR/mlc-llm"

# Ensure models directory exists
mkdir -p "$MODELS_DIR"

echo "============================================"
echo "WebLLM Model Compilation Script"
echo "============================================"
echo ""
echo "This script will:"
echo "1. Clone models from HuggingFace"
echo "2. Convert weights to MLC format"
echo "3. Compile WASM with prefill_all_logits support"
echo ""

# Use the venv's python with mlc_llm module
VENV_PYTHON="$ROOT_DIR/.venv/bin/python"

if [ ! -f "$VENV_PYTHON" ]; then
    echo "ERROR: Python venv not found at $ROOT_DIR/.venv"
    echo "Please create with: python -m venv .venv && .venv/bin/pip install mlc-llm-nightly-cpu mlc-ai-nightly-cpu"
    exit 1
fi

# Clear PYTHONPATH to avoid conflicts with local source
export PYTHONPATH=""

# Source emsdk environment if available
if [ -f "$ROOT_DIR/emsdk/emsdk_env.sh" ]; then
    source "$ROOT_DIR/emsdk/emsdk_env.sh" > /dev/null
fi

# Find the installed mlc_llm package path to set MLC_LLM_SOURCE_DIR
# This is crucial to match the installed runtime version and avoid duplicate symbols
INSTALLED_MLC_LLM_PATH=$("$VENV_PYTHON" -c "import os, mlc_llm; print(os.path.dirname(mlc_llm.__file__))")
if [ -z "$INSTALLED_MLC_LLM_PATH" ]; then
    echo "WARNING: Could not find installed mlc_llm path. Fallback to local source."
    export MLC_LLM_SOURCE_DIR="$MLC_LLM_DIR"
else
    echo "Using installed mlc_llm at: $INSTALLED_MLC_LLM_PATH"
    export MLC_LLM_SOURCE_DIR="$INSTALLED_MLC_LLM_PATH"
fi

# Define a function to replace the command using the installed package
mlc_llm() {
    "$VENV_PYTHON" -m mlc_llm "$@"
}

# Check if git-lfs is installed
if ! git lfs version &> /dev/null; then
    echo "ERROR: git-lfs is not installed!"
    echo "HuggingFace models require git-lfs to download large weights."
    echo ""
    echo "Please install it:"
    echo "  brew install git-lfs  # macOS"
    echo "  sudo apt install git-lfs  # Ubuntu/Debian"
    echo ""
    echo "Then initialize it:"
    echo "  git lfs install"
    exit 1
fi

# Model configurations
# Format: "model_id|output_name|quantization|conv_template|prefill_chunk_size"
MODELS=(
    "Qwen/Qwen2.5-1.5B|Qwen2.5-1.5B|q4f16_1|LM|4096"
    "mistralai/Mistral-7B-v0.3|Mistral-7B-v0.3|q4f16_1|mistral_default|4096"
    "google/gemma-2-9b|Gemma-2-9B|q4f32_1|gemma_instruction|4096"
)

compile_model() {
    local model_spec="$1"
    IFS='|' read -r model_id output_name quantization conv_template prefill_chunk_size <<< "$model_spec"
    
    local output_dir="$MODELS_DIR/${output_name}-${quantization}"
    local wasm_output="$output_dir/${output_name}.wasm"
    
    echo ""
    echo "============================================"
    echo "Compiling: $model_id"
    echo "  Output: $output_name"
    echo "  Quantization: $quantization"
    echo "  Conv Template: $conv_template"
    echo "  Prefill Chunk Size: $prefill_chunk_size"
    echo "============================================"
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Step 1: Clone or update model from HuggingFace
    local model_path="$ROOT_DIR/downloads/$(basename "$model_id")"
    if [ ! -d "$model_path" ]; then
        echo ""
        echo "[Step 1/4] Cloning model from HuggingFace..."
        mkdir -p "$ROOT_DIR/downloads"
        git clone "https://huggingface.co/$model_id" "$model_path"
    else
        echo ""
        echo "[Step 1/4] Model already cloned at $model_path"
        echo "Updating/Verifying LFS files..."
        cd "$model_path" && git lfs pull && cd - > /dev/null
    fi

    # Step 2: Convert weights
    echo ""
    echo "[Step 2/4] Converting weights..."
    mlc_llm convert_weight "$model_path" \
        --quantization "$quantization" \
        --output "$output_dir"
    
    # Step 3: Generate config
    echo ""
    echo "[Step 3/4] Generating config..."
    mlc_llm gen_config "$model_path" \
        --quantization "$quantization" \
        --conv-template "$conv_template" \
        --prefill-chunk-size "$prefill_chunk_size" \
        --output "$output_dir"
    
    # Step 4: Compile to WASM
    echo ""
    echo "[Step 4/4] Compiling to WASM..."
    mlc_llm compile "$output_dir/mlc-chat-config.json" \
        --device webgpu \
        --output "$wasm_output" \
        --overrides "tensor_parallel_shards=1"
    
    echo ""
    echo "✓ Completed: $output_name"
    echo "  Config: $output_dir/mlc-chat-config.json"
    echo "  WASM: $wasm_output"
    echo "  Weights: $output_dir/params_shard_*.bin"
}

# Parse command line arguments
if [ $# -eq 0 ]; then
    echo "Usage: $0 [all|qwen|mistral|gemma]"
    echo ""
    echo "Models:"
    echo "  qwen    - Qwen2.5-1.5B (1.8GB VRAM, lightweight)"
    echo "  mistral - Mistral-7B-v0.3 (4.8GB VRAM, medium)"
    echo "  gemma   - Gemma-2-9B (7.6GB VRAM, heavy, requires HF login)"
    echo "  all     - Compile all models"
    echo ""
    exit 0
fi

case "$1" in
    all)
        for model in "${MODELS[@]}"; do
            compile_model "$model"
        done
        ;;
    qwen)
        compile_model "${MODELS[0]}"
        ;;
    mistral)
        compile_model "${MODELS[1]}"
        ;;
    gemma)
        echo "NOTE: Gemma-2-9B is a gated model. Make sure you have:"
        echo "  1. Accepted the license at https://huggingface.co/google/gemma-2-9b"
        echo "  2. Run 'huggingface-cli login' with your token"
        echo ""
        compile_model "${MODELS[2]}"
        ;;
    *)
        echo "Unknown model: $1"
        echo "Use: all, qwen, mistral, or gemma"
        exit 1
        ;;
esac

echo ""
echo "============================================"
echo "Compilation Complete!"
echo "============================================"
echo ""
echo "Next steps:"
echo "1. Copy the WASM file to your app's public folder"
echo "2. Update your app config to point to the new model"
echo ""
echo "Example config for your React app:"
echo ""
echo "const appConfig = {"
echo "  model_list: [{"
echo "    model: 'https://huggingface.co/mlc-ai/...',"
echo "    model_id: 'your-model-id',"
echo "    model_lib: '/YourModel.wasm',"
echo "  }]"
echo "};"
