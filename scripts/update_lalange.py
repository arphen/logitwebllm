#!/usr/bin/env python3
"""Script to add GPT-2 Medium support to lalange project"""

# Read the file
with open('/Users/swozny/Projects/lalange/src/core/ai/webllm.ts', 'r') as f:
    content = f.read()

# Check if gpt2 is already in MODEL_INFO
if 'gpt2:' not in content:
    # Add gpt2 to MODEL_INFO - find the closing of qwen section
    old_qwen = '''qwen: {
        id: "Qwen2.5-1.5B-logprobs",
        name: "Qwen 2.5 1.5B (Logprobs)",
        size: "980 MB",
        description: "Higher quality 1.5B model."
    }
} as const;'''
    
    new_with_gpt2 = '''qwen: {
        id: "Qwen2.5-1.5B-logprobs",
        name: "Qwen 2.5 1.5B (Logprobs)",
        size: "980 MB",
        description: "Higher quality 1.5B model."
    },
    gpt2: {
        id: "GPT2-Medium-logprobs",
        name: "GPT-2 Medium (Logprobs)",
        size: "230 MB",
        description: "Lightweight 355M model, fast loading."
    }
} as const;'''
    
    content = content.replace(old_qwen, new_with_gpt2)
    print("Added gpt2 to MODEL_INFO")

# Add gpt2 to MODEL_MAPPING if not present
if 'gpt2: MODEL_INFO.gpt2.id' not in content:
    content = content.replace(
        'qwen: MODEL_INFO.qwen.id,\n} as const;',
        'qwen: MODEL_INFO.qwen.id,\n    gpt2: MODEL_INFO.gpt2.id,\n} as const;'
    )
    print("Added gpt2 to MODEL_MAPPING")

# Write back
with open('/Users/swozny/Projects/lalange/src/core/ai/webllm.ts', 'w') as f:
    f.write(content)

print("Done! GPT-2 Medium integration complete.")
