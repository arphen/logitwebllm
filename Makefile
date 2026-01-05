.PHONY: install run build clean wasm copy-wasm

# Paths
ROOT_DIR := $(shell pwd)
EMSDK_DIR := $(ROOT_DIR)/emsdk
MLC_LLM_DIR := $(ROOT_DIR)/mlc-llm
WEB_LLM_DIR := $(ROOT_DIR)/web-llm
REACT_APP_DIR := $(WEB_LLM_DIR)/examples/react-logit-demo
TVM_SOURCE_DIR := $(MLC_LLM_DIR)/3rdparty/tvm

# Install dependencies
install:
	cd $(REACT_APP_DIR) && npm install

# Run the React application
run:
	cd $(REACT_APP_DIR) && npm run dev

# Build the React application
build:
	cd $(REACT_APP_DIR) && npm run build

# Clean the React application
clean:
	cd $(REACT_APP_DIR) && rm -rf dist node_modules

# Recompile the WASM runtime and copy it to the React app
wasm:
	# Build WASM
	source $(EMSDK_DIR)/emsdk_env.sh && \
	TVM_SOURCE_DIR=$(TVM_SOURCE_DIR) make -C $(MLC_LLM_DIR)/web clean && \
	TVM_SOURCE_DIR=$(TVM_SOURCE_DIR) make -C $(MLC_LLM_DIR)/web
	# Copy to React App
	mkdir -p $(REACT_APP_DIR)/public
	cp $(MLC_LLM_DIR)/web/dist/wasm/mlc_wasm_runtime.wasm $(REACT_APP_DIR)/public/

# Just copy the existing WASM (if already built)
copy-wasm:
	mkdir -p $(REACT_APP_DIR)/public
	cp $(MLC_LLM_DIR)/web/dist/wasm/mlc_wasm_runtime.wasm $(REACT_APP_DIR)/public/
