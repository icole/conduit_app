package com.colecoding.conduit.ui

import android.view.View
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat

/**
 * Pads [this] view by the system bar and display cutout insets on the given
 * [edges], keeping whatever padding the layout already declared.
 *
 * Apps targeting Android 16 (API 36) cannot opt out of edge-to-edge:
 * `android:windowOptOutEdgeToEdgeEnforcement` is deprecated and ignored, so
 * every activity has to keep its own chrome clear of the system bars.
 *
 * On API 28-34 the decor view still consumes these insets before they reach the
 * content root, so the view receives zeroes and this is a no-op.
 *
 * The insets are deliberately *not* consumed, so sibling and descendant views
 * (the bottom navigation, Stream Chat's message composer) still receive them.
 */
fun View.padForSystemBars(edges: Set<Edge> = Edge.ALL) {
    val declared = EdgePadding(paddingLeft, paddingTop, paddingRight, paddingBottom)

    ViewCompat.setOnApplyWindowInsetsListener(this) { view, windowInsets ->
        val bars = windowInsets.getInsets(
            WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout()
        )
        val padding = declared.plusInsets(
            EdgePadding(bars.left, bars.top, bars.right, bars.bottom),
            edges
        )

        view.setPadding(padding.left, padding.top, padding.right, padding.bottom)
        windowInsets
    }

    ViewCompat.requestApplyInsets(this)
}
