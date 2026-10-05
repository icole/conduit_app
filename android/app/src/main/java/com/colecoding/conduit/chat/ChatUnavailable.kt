package com.colecoding.conduit.chat

import org.json.JSONObject

/**
 * Why chat can't load, from the server's 403 when it won't issue a chat token
 * (community awaiting approval, chat off for the community, email unverified),
 * worded for the member.
 */
object ChatUnavailable {
    private const val TRY_AGAIN = "Chat couldn't load. Check your connection and try again."

    fun message(reason: String?): String = when (reason) {
        "community_not_active" -> "Chat opens once your community is approved."
        "chat_disabled" -> "Chat isn't turned on for your community."
        "email_unverified" -> "Verify your email address to use chat: use the link we emailed you, or send a new one from Account."
        else -> TRY_AGAIN
    }

    fun reasonFrom(body: String?): String? =
        body?.let { runCatching { JSONObject(it).optString("error").ifBlank { null } }.getOrNull() }
}
