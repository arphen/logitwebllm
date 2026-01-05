#!/bin/bash
# Check WASM imports vs what web-llm provides
# This helps catch LinkError issues before running the server

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
WASM_FILE="$ROOT_DIR/mlc-llm/web/dist/wasm/mlc_wasm_runtime.wasm"
EMSDK_DIR="$ROOT_DIR/emsdk"
WASM_DIS="$EMSDK_DIR/upstream/bin/wasm-dis"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "============================================"
echo "WASM Import Analysis"
echo "============================================"

if [ ! -f "$WASM_FILE" ]; then
    echo -e "${RED}Error: WASM file not found at $WASM_FILE${NC}"
    exit 1
fi

if [ ! -f "$WASM_DIS" ]; then
    echo -e "${RED}Error: wasm-dis not found at $WASM_DIS${NC}"
    echo "Make sure emsdk is installed"
    exit 1
fi

echo "WASM file: $WASM_FILE"
echo "Size: $(du -h "$WASM_FILE" | cut -f1)"
echo ""

# Extract all imports
echo "Extracting imports..."
IMPORTS=$("$WASM_DIS" "$WASM_FILE" 2>&1 | grep -E '^\s*\(import "env"' | sed 's/.*"env" "\([^"]*\)".*/\1/')

# Count imports
TOTAL=$(echo "$IMPORTS" | wc -l | tr -d ' ')
echo "Total env imports: $TOTAL"
echo ""

# Demangle C++ symbols if c++filt is available
if command -v c++filt &> /dev/null; then
    echo "============================================"
    echo "Demangled C++ imports:"
    echo "============================================"
    echo "$IMPORTS" | while read -r sym; do
        if [[ "$sym" == _Z* ]]; then
            demangled=$(echo "$sym" | c++filt)
            echo -e "  ${YELLOW}$demangled${NC}"
        fi
    done
else
    echo "============================================"
    echo "Mangled C++ imports (install c++filt to demangle):"
    echo "============================================"
    echo "$IMPORTS" | while read -r sym; do
        if [[ "$sym" == _Z* ]]; then
            echo "  $sym"
        fi
    done
fi

echo ""
echo "============================================"
echo "These functions MUST be provided by the JS runtime"
echo "or another WASM module linked at runtime."
echo ""
echo "If you see LinkError in the browser, the missing"
echo "function name will match one of these imports."
echo "============================================"

# Group by namespace
echo ""
echo "============================================"
echo "Grouped by namespace:"
echo "============================================"

echo -e "\n${GREEN}mlc::llm::Tokenizer:${NC}"
echo "$IMPORTS" | grep "mlc3llm.*Tokenizer" | while read -r sym; do
    echo "  $(echo "$sym" | c++filt 2>/dev/null || echo "$sym")"
done

echo -e "\n${GREEN}mlc::llm::serve::EngineAction:${NC}"
echo "$IMPORTS" | grep "mlc3llm5serve12EngineAction" | while read -r sym; do
    echo "  $(echo "$sym" | c++filt 2>/dev/null || echo "$sym")"
done

echo -e "\n${GREEN}xgrammar:${NC}"
echo "$IMPORTS" | grep "xgrammar" | while read -r sym; do
    echo "  $(echo "$sym" | c++filt 2>/dev/null || echo "$sym")"
done

echo -e "\n${GREEN}tvm::runtime:${NC}"
echo "$IMPORTS" | grep "tvm7runtime\|tvm3ffi" | while read -r sym; do
    echo "  $(echo "$sym" | c++filt 2>/dev/null || echo "$sym")"
done

echo ""
