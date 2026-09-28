package id.steveimm.pocketpilot.tool.action

import id.steveimm.pocketpilot.model.Bounds
import id.steveimm.pocketpilot.model.PerceptionElement
import id.steveimm.pocketpilot.model.Point
import id.steveimm.pocketpilot.model.ScreenSnapshot
import id.steveimm.pocketpilot.platform.SemanticTargetHint
import id.steveimm.pocketpilot.perception.mergedText
import id.steveimm.pocketpilot.perception.normalizeForMatching

/** Resolves a Target to screen coordinates. */
object TargetResolver {
    sealed interface ResolveResult {
        data class Resolved(
            val point: Point,
            val bounds: Bounds? = null,
            val semanticHint: SemanticTargetHint? = null,
            val warnings: List<String> = emptyList(),
            val coordinateFallback: Boolean = false
        ) : ResolveResult

        data class NotFound(val reason: String) : ResolveResult
        data class Ambiguous(val reason: String) : ResolveResult
    }

    fun resolve(target: Target, snapshot: ScreenSnapshot?): ResolveResult = when (target) {
        is Target.Coordinate -> ResolveResult.Resolved(Point(target.x, target.y))
        is Target.ElementIndex -> resolveSemantic(
            semantic = resolveElementIndex(target.index, snapshot),
            hint = target.coordinateHint
        )
        is Target.Text -> resolveSemantic(
            semantic = resolveText(target.text, target.textIndex, snapshot),
            hint = target.coordinateHint
        )
    }

    private fun resolveSemantic(
        semantic: ResolveResult,
        hint: Target.Coordinate?
    ): ResolveResult {
        return when (semantic) {
            is ResolveResult.Resolved -> semantic
            is ResolveResult.NotFound -> {
                if (hint != null) {
                    ResolveResult.Resolved(
                        point = Point(hint.x, hint.y),
                        bounds = null,
                        semanticHint = null,
                        warnings = listOf(
                            "Used coordinate fallback after semantic target failed: ${semantic.reason}"
                        ),
                        coordinateFallback = true
                    )
                } else {
                    semantic
                }
            }
            is ResolveResult.Ambiguous -> semantic
        }
    }

    private fun resolveElementIndex(index: Int, snapshot: ScreenSnapshot?): ResolveResult {
        val snap = snapshot ?: return ResolveResult.NotFound(
            "Cannot resolve element_index $index: no snapshot available"
        )
        if (!snap.hasElements) {
            return ResolveResult.NotFound(
                "Cannot use element_index: no elements on screen. Use coordinate (x, y) instead."
            )
        }
        val element = snap.elements.firstOrNull { it.index == index }
            ?: return ResolveResult.NotFound(buildElementMissingReason(index, snap))
        return resolveElementPoint(element)
    }

    private fun resolveText(text: String, textIndex: Int, snapshot: ScreenSnapshot?): ResolveResult {
        val snap = snapshot ?: return ResolveResult.NotFound(
            "Cannot resolve text \"$text\": no snapshot available"
        )
        if (!snap.hasElements) {
            return ResolveResult.NotFound(
                "Cannot use text targeting: no elements on screen. Use coordinate (x, y) instead."
            )
        }
        val normalizedTarget = normalizeForMatching(text)
        val promptMatches = snap.elements.filter { element ->
            normalizeForMatching(mergedText(element)) == normalizedTarget
        }
        val matches = if (promptMatches.isNotEmpty()) {
            promptMatches
        } else {
            snap.elements.filter { element ->
                normalizeForMatching(element.description) == normalizedTarget ||
                    normalizeForMatching(element.hintText) == normalizedTarget
            }
        }
        val element = matches.getOrNull(textIndex)
            ?: return ResolveResult.NotFound(
                "Text \"$text\" index $textIndex not found (matched ${matches.size} elements)"
            )
        return resolveElementPoint(element)
    }

    private fun buildElementMissingReason(index: Int, snapshot: ScreenSnapshot): String {
        val available = snapshot.elements.map { it.index }
        val preview = available.take(20).joinToString(", ")
        val more = if (available.size > 20) " ... and ${available.size - 20} more" else ""
        return "Element not found: index $index. Available: $preview$more"
    }

    private fun resolveElementPoint(element: PerceptionElement): ResolveResult.Resolved {
        val hint = SemanticTargetHint(
            resourceId = element.resourceId,
            text = element.text,
            description = element.description,
            className = element.className,
            bounds = element.bounds
        )
        return ResolveResult.Resolved(element.center, bounds = element.bounds, semanticHint = hint)
    }
}
