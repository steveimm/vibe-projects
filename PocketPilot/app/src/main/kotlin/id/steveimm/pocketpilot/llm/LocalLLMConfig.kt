package id.steveimm.pocketpilot.llm

import ai.liquid.leap.GenerationOptions

/** Configuration for local LLM. */
data class LocalLLMConfig(
    /** Model slug (e.g., "LFM2.5-1.2B-Instruct") */
    val modelSlug: String = "LFM2.5-1.2B-Instruct",
    /** Quantization slug (e.g., "Q4_K_M") - must match Leap Model Library */
    val quantizationSlug: String = "Q4_K_M",
    /** Optional generation options (e.g., functionCallParser, temperature). When null, the SDK defaults from the model manifest are
     * used. */
    val generationOptions: GenerationOptions? = null
)
