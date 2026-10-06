package com.colecoding.conduit.ui

/**
 * The website's colours (app/assets/tailwind/theme.css), for the native bars,
 * sheets and chat that sit against its pages. Paper, ink and green must equal
 * the theme's exactly; NativePaletteTest checks them. res/values/colors.xml
 * repeats these for XML and Stream's own resources. Palette.swift is the iOS twin.
 */
object Palette {
    /** The page, and the bars that meet it */
    val paper = 0xFFF8F4EC.toInt()

    /** Cards, sheets and chat bubbles on the paper */
    val surface = 0xFFFEFDFA.toInt()
    val ink = 0xFF160D08.toInt()

    /** Secondary text, at the website's 70% ink */
    val muted = 0xFF6A635D.toInt()

    /** A tab or icon that isn't the current one */
    val inactive = 0xFF5A524C.toInt()

    /** Chevrons and other quiet marks */
    val faint = 0xFF9C958E.toInt()
    val line = 0xFFE9E2D7.toInt()
    val divider = 0xFFD6CFC5.toInt()

    /** Actions and the current tab: the website's forest green */
    val green = 0xFF265C40.toInt()

    /** The current tab's pill, your own chat bubble */
    val greenTint = 0xFFDCE3DB.toInt()

    /** Counts that need you (the bell), like the website's */
    val terracotta = 0xFFA94524.toInt()
    val destructive = 0xFFAC2724.toInt()
}
