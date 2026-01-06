#!/bin/bash
# install_logit_support.sh
# 
# Usage in target app:
# curl -sL https://raw.githubusercontent.com/arpheno/logitwebllm/main/scripts/install_logit_support.sh | bash

set -e

echo "📦 Installing modified WebLLM from GitHub..."
npm install github:arpheno/web-llm

echo "📥 Downloading Custom TinyLlama WASM Runtime..."
mkdir -p public
curl -L https://github.com/arpheno/logitwebllm/raw/main/models/TinyLlama-1.1B-Chat-v1.0-q4f16_1/TinyLlama-1.1B-minimal.wasm -o public/TinyLlama-1.1B.wasm

echo "✅ Done! You can now import '@mlc-ai/web-llm' and use '/TinyLlama-1.1B.wasm' as your model_lib."
