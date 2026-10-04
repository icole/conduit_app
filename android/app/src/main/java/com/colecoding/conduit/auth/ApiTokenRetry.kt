package com.colecoding.conduit.auth

/** What the server said to a request made with the app's API token. */
sealed interface ApiReply<out T> {
    data class Ok<T>(val value: T) : ApiReply<T>

    /** The token was refused, even after refreshing it: the member has to sign in again. */
    data object Unauthorized : ApiReply<Nothing>

    /** A network or server problem; worth trying again later. */
    data object Failed : ApiReply<Nothing>
}

/**
 * Makes a request with the API token. The token lasts 30 days; when the server
 * refuses it, refresh it once (the server allows that for a week after expiry)
 * and try again.
 */
object ApiTokenRetry {
    fun <T> call(token: String?, refresh: () -> String?, request: (String) -> ApiReply<T>): ApiReply<T> {
        token ?: return ApiReply.Unauthorized
        val reply = request(token)
        if (reply != ApiReply.Unauthorized) return reply

        val refreshed = refresh() ?: return ApiReply.Unauthorized
        return request(refreshed)
    }
}
