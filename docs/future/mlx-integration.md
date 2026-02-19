# MLX Local LLM Integration

## Overview

On-device LLM inference via Apple MLX framework for AI-powered prompt analysis. No cloud dependency — runs entirely on Apple Silicon.

## Dependencies

- `mlx-swift` and `mlx-swift-examples` SPM packages
- Model: qwen3-coder from Hugging Face (or similar small coding-focused model)
- Apple Silicon Mac required (MLX limitation)

## Components

### ModelManager Service
- Download model from HF on first use (not first launch)
- Store in `~/Library/Application Support/Tenrec Terminal/Models/`
- Progress UI during download (sheet with progress bar)
- Model lifecycle: check → download → load → inference → unload
- Settings: choose model, manage storage (delete/redownload)
- Error handling: download failures, insufficient disk, load failures

### LLMInferenceService Protocol
```swift
protocol LLMInferenceService {
    func generate(prompt: String, maxTokens: Int) async throws -> String
    func generateStream(prompt: String, maxTokens: Int) -> AsyncStream<String>
}
```
- MLX implementation with configurable temperature, top-p
- Cancellation support via Task cancellation

### AI Prompt Tools (Detail Pane)
- **Rate Effectiveness**: meta-prompt evaluates the prompt, returns score + reasoning
- **Suggest Rewrite**: generates improved version with explanations
- **Simplify / Expand**: quick actions for prompt refinement
- **Validate Parameters** (templates): checks if template parameters are complete
- **Suggest Parameters** (templates): recommends additional parameters

### UX
- Results display inline with accept/reject actions
- Streaming output shown progressively
- Loading states, cancellation button
- Graceful degradation when model not downloaded

## Considerations

- Model size: ~2-4GB download, ~4-8GB RAM during inference
- First inference latency: model loading takes 5-15s
- Keep model loaded while app is active, unload on memory pressure
- Rate limit: debounce rapid repeated calls
