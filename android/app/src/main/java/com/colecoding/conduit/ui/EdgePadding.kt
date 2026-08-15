package com.colecoding.conduit.ui

/**
 * Padding on the four edges of a view, in pixels.
 *
 * Kept free of Android types so the inset arithmetic can be unit tested on the
 * JVM without an emulator. See [EdgePaddingTest].
 */
data class EdgePadding(
    val left: Int,
    val top: Int,
    val right: Int,
    val bottom: Int
)

enum class Edge {
    LEFT, TOP, RIGHT, BOTTOM;

    companion object {
        val ALL: Set<Edge> = entries.toSet()
        val VERTICAL: Set<Edge> = setOf(TOP, BOTTOM)
    }
}

/**
 * Adds [insets] to the receiver on the given [edges].
 *
 * The receiver must always be the padding the layout was *declared* with, never
 * the view's current padding. WindowInsets are dispatched repeatedly (rotation,
 * keyboard, gesture-mode change) and reading back current padding would make it
 * accumulate a little more on every pass.
 */
fun EdgePadding.plusInsets(insets: EdgePadding, edges: Set<Edge>): EdgePadding =
    EdgePadding(
        left = left + if (Edge.LEFT in edges) insets.left else 0,
        top = top + if (Edge.TOP in edges) insets.top else 0,
        right = right + if (Edge.RIGHT in edges) insets.right else 0,
        bottom = bottom + if (Edge.BOTTOM in edges) insets.bottom else 0
    )
