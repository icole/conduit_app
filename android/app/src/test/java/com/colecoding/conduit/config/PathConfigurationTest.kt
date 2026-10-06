package com.colecoding.conduit.config

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.io.File

/** The app's path rules, applied as Hotwire does: every matching rule, later ones winning. */
class PathConfigurationTest {
    private val rules = JSONObject(File("src/main/assets/json/path-configuration.json").readText()).getJSONArray("rules")

    private fun properties(path: String): Map<String, Any> {
        val merged = mutableMapOf<String, Any>()
        for (i in 0 until rules.length()) {
            val rule = rules.getJSONObject(i)
            val patterns = rule.getJSONArray("patterns")
            val matches = (0 until patterns.length()).any {
                Regex(patterns.getString(it), RegexOption.IGNORE_CASE).containsMatchIn(path)
            }
            if (matches) {
                val properties = rule.getJSONObject("properties")
                properties.keys().forEach { merged[it] = properties.get(it) }
            }
        }
        return merged
    }

    @Test
    fun `Notifications opens as a sheet, so it closes when you leave it`() {
        assertEquals("modal", properties("/notifications")["context"])
        assertEquals("hotwire://fragment/web_modal", properties("/notifications")["uri"])
    }

    @Test
    fun `what a notification opens is an ordinary page`() {
        assertNull(properties("/notifications/5")["context"])
        assertNull(properties("/meals/5")["context"])
    }
}
