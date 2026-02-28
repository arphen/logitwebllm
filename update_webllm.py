#!/usr/bin/env python3
content = open('/Users/swozny/Projects/lalange/src/core/ai/webllm.ts', 'r').read()

# 1. Add Llama config after GPT2_MEDIUM_CONFIG  
llama_block = '''
// Llama 3.2 1B with reduced 32k vocabulary - good balance of quality and size
const getLlama32Config = () => {
    const origin = typeof window !== 'undefined' ? window.location.origin : '';
    return {
        model: `${origin}/models/Llama-3.2-1B-vocab32k-q4f16_1`,
        model_id: "Llama-3.2-1B-logprobs",
        model_lib: "/models/Llama-3.2-1B-vocab32k-q4f16_1/Llama-3.2-1B-vocab32k.wasm",
        vram_required_MB: 900,
        low_resource_required: true,
    };
};

const LLAMA_32_CONFIG = {
    model: "/models/Llama-3.2-1B-vocab32k-q4f16_1",
    model_id: "Llama-3.2-1B-logprobs",
    model_lib: "/models/Llama-3.2-1B-vocab32k-q4f16_1/Llama-3.2-1B-vocab32k.wasm",
    vram_required_MB: 900,
    low_resource_required: true,
};

// Shared app config'''

# Find where to insert - after the GPT2_MEDIUM_CONFIG closing brace
search = '''const GPT2_MEDIUM_CONFIG = {
    model: "/models/GPT2-Medium-q4f16_1",
    model_id: "GPT2-Medium-logprobs",
    model_lib: "/models/GPT2-Medium-q4f16_1/GPT2-Medium.wasm",
    vram_required_MB: 300,
    low_resource_required: true,
};

// Shared app config'''

content = content.replace(search, search.replace('// Shared app config', '') + llama_block)

# 2. Update APP_CONFIG
content = content.replace(
    'model_list: [TINYLLAMA_LOGPROBS_CONFIG, QWEN_LOGPROBS_CONFIG, GPT2_MEDIUM_CONFIG],',
    'model_list: [TINYLLAMA_LOGPROBS_CONFIG, QWEN_LOGPROBS_CONFIG, GPT2_MEDIUM_CONFIG, LLAMA_32_CONFIG],'
)

# 3. Update getAppConfig
content = content.replace(
    'model_list: [TINYLLAMA_LOGPROBS_CONFIG, QWEN_LOGPROBS_CONFIG, getGPT2MediumConfig()],',
    'model_list: [TINYLLAMA_LOGPROBS_CONFIG, QWEN_LOGPROBS_CONFIG, getGPT2MediumConfig(), getLlama32Config()],'
)

# 4. Add llama to MODEL_INFO - find the closing of gpt2 and add llama
content = content.replace(
    '''gpt2: {
        id: "GPT2-Medium-logprobs",
        name: "GPT-2 Medium (Logprobs)",
        size: "230 MB",
        description: "Lightweight 355M model, fast loading."
    }
} as const;''',
    '''gpt2: {
        id: "GPT2-Medium-logprobs",
        name: "GPT-2 Medium (Logprobs)",
        size: "230 MB",
        description: "Lightweight 355M model, fast loading."
    },
    llama: {
        id: "Llama-3.2-1B-logprobs",
        name: "Llama 3.2 1B (Logprobs)",
        size: "544 MB",
        description: "Llama 3.2 1B with 32k vocab, good quality."
    }
} as const;'''
)

# 5. Add llama to MODEL_MAPPING
content = content.replace(
    '''export const MODEL_MAPPING = {
    tiny: MODEL_INFO.tiny.id,
    qwen: MODEL_INFO.qwen.id,
    gpt2: MODEL_INFO.gpt2.id,
} as const;''',
    '''export const MODEL_MAPPING = {
    tiny: MODEL_INFO.tiny.id,
    qwen: MODEL_INFO.qwen.id,
    gpt2: MODEL_INFO.gpt2.id,
    llama: MODEL_INFO.llama.id,
} as const;'''
)

# 6. Update modelConfig selection
content = content.replace(
    '''const modelConfig = tier === 'tiny' ? TINYLLAMA_LOGPROBS_CONFIG :
                        tier === 'qwen' ? QWEN_LOGPROBS_CONFIG : 
                        GPT2_MEDIUM_CONFIG;''',
    '''const modelConfig = tier === 'tiny' ? TINYLLAMA_LOGPROBS_CONFIG :
                        tier === 'qwen' ? QWEN_LOGPROBS_CONFIG :
                        tier === 'gpt2' ? GPT2_MEDIUM_CONFIG :
                        LLAMA_32_CONFIG;'''
)

with open('/Users/swozny/Projects/lalange/src/core/ai/webllm.ts', 'w') as f:
    f.write(content)

print("Updated successfully!")
