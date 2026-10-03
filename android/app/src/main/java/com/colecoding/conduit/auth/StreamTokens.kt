package com.colecoding.conduit.auth

import io.getstream.chat.android.client.token.TokenProvider
import java.io.IOException

/**
 * Chat tokens expire within the hour (CON-80), so Stream asks for a new one
 * whenever it reconnects. The first comes from the fetch that started the
 * connection; after that, each one is fetched fresh. Stream calls this off the
 * main thread, so [fetch] may block.
 */
class StreamTokens(first: String, private val fetch: () -> String?) : TokenProvider {
    private var first: String? = first

    @Synchronized
    override fun loadToken(): String {
        first?.let { first = null; return it }
        return fetch() ?: throw IOException("Couldn't get a chat token")
    }
}
