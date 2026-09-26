package com.colecoding.conduit.chat

import android.content.Context
import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.Drawable
import androidx.core.content.ContextCompat
import io.getstream.chat.android.models.Channel
import io.getstream.chat.android.ui.widgets.avatar.ChannelAvatarRenderer

/**
 * Channel avatars show a "#" instead of Stream's collage of member photos.
 * Every channel holds the whole community, so the collage looked the same
 * everywhere and only added clutter; the web chat lists channels as "# name"
 * too. A channel that has its own image still shows it.
 */
object ChannelHashAvatar {
    fun showsHash(channel: Channel): Boolean = channel.image.isBlank()

    /** Set as ChatUI.channelAvatarRenderer before any chat screen is built. */
    val renderer = ChannelAvatarRenderer { _, channel, _, targetProvider ->
        val view = targetProvider.regular()
        val hash = HashDrawable(view.context)
        if (showsHash(channel)) {
            view.setImageDrawable(hash)
        } else {
            view.setAvatar(channel.image, placeholder = hash)
        }
    }

    // Stream's own grey colors, which have dark mode variants
    private class HashDrawable(context: Context) : Drawable() {
        private val background = ContextCompat.getColor(
            context, io.getstream.chat.android.ui.R.color.stream_ui_grey_whisper
        )
        private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = ContextCompat.getColor(context, io.getstream.chat.android.ui.R.color.stream_ui_grey)
            typeface = Typeface.DEFAULT_BOLD
            textAlign = Paint.Align.CENTER
        }

        override fun draw(canvas: Canvas) {
            canvas.drawColor(background)
            val bounds = bounds
            textPaint.textSize = bounds.height() * 0.45f
            val baseline = bounds.exactCenterY() - (textPaint.descent() + textPaint.ascent()) / 2
            canvas.drawText("#", bounds.exactCenterX(), baseline, textPaint)
        }

        override fun setAlpha(alpha: Int) {
            textPaint.alpha = alpha
        }

        override fun setColorFilter(colorFilter: ColorFilter?) {
            textPaint.colorFilter = colorFilter
        }

        @Deprecated("Deprecated in Java")
        override fun getOpacity(): Int = PixelFormat.OPAQUE
    }
}
