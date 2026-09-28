package id.steveimm.pocketpilot.browser.cdp

import id.steveimm.pocketpilot.browser.cdp.shizuku.PageTarget

object ChromeCdpTarget {
    private val INTERNAL_PREFIXES = listOf(
        "chrome://",
        "chrome-untrusted://",
        "devtools://",
        "chrome-extension://",
        "about:",
    )

    fun isRealPage(type: String, url: String): Boolean =
        type == "page" && INTERNAL_PREFIXES.none { url.startsWith(it) }

    fun firstRealPage(targets: List<PageTarget>): PageTarget? =
        targets.firstOrNull { isRealPage(it.type, it.url) }
}
