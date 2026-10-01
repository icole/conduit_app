package com.colecoding.conduit.fragments

import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import androidx.fragment.app.Fragment
import com.colecoding.conduit.MainActivity
import com.colecoding.conduit.R
import com.colecoding.conduit.auth.AuthManager

/**
 * The Account tab: who you're signed in as, then grouped rows like the
 * platform's own settings screens.
 */
class AccountFragment : Fragment() {

    private val page = Color.parseColor("#FAF7F5")
    private val ink = Color.parseColor("#291334")
    private val muted = Color.parseColor("#6B6470")
    private val destructive = Color.parseColor("#B3261E")

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        val context = requireContext()
        val name = AuthManager.getUserName(context).orEmpty()
        val email = AuthManager.getUserEmail(context).orEmpty()
        val community = AuthManager.getCommunitySlug(context).orEmpty()

        val column = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(24), dp(16), dp(24))
        }

        column.addView(TextView(context).apply {
            text = "Account"
            textSize = 28f
            setTextColor(ink)
            setPadding(dp(4), 0, 0, dp(20))
        })

        column.addView(surface().apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(16), dp(16), dp(16), dp(16))
            addView(avatar(name))
            addView(LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(16), 0, 0, 0)
                addView(TextView(context).apply {
                    text = name.ifBlank { "Signed in" }
                    textSize = 18f
                    setTypeface(typeface, Typeface.BOLD)
                    setTextColor(ink)
                })
                if (email.isNotBlank()) addView(TextView(context).apply {
                    text = email
                    textSize = 14f
                    setTextColor(muted)
                })
            })
        })

        column.addView(sectionLabel(community.replace('-', ' ').replaceFirstChar { it.uppercase() }.ifBlank { "Community" }))
        column.addView(rows(
            Row("Account settings", chevron = true) { (activity as? MainActivity)?.openInApp("/account") },
            Row("Switch community") { (activity as? MainActivity)?.switchCommunity() }
        ))

        column.addView(View(context).apply { minimumHeight = dp(24) })
        column.addView(rows(Row(getString(R.string.logout), color = destructive) { showLogoutConfirmation() }))

        return ScrollView(context).apply {
            setBackgroundColor(page)
            addView(column)
        }
    }

    private data class Row(
        val title: String,
        val color: Int? = null,
        val chevron: Boolean = false,
        val onClick: () -> Unit
    )

    private fun rows(vararg rows: Row) = surface().apply {
        orientation = LinearLayout.VERTICAL
        rows.forEachIndexed { index, row ->
            if (index > 0) addView(View(context).apply {
                setBackgroundColor(Color.parseColor("#EFEAE6"))
                layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 1).apply {
                    marginStart = dp(16)
                }
            })
            addView(TextView(context).apply {
                text = row.title
                textSize = 16f
                setTextColor(row.color ?: ink)
                gravity = Gravity.CENTER_VERTICAL
                minHeight = dp(56)
                setPadding(dp(16), 0, dp(16), 0)
                if (row.chevron) {
                    setCompoundDrawablesRelativeWithIntrinsicBounds(0, 0, R.drawable.ic_chevron_right, 0)
                }
                setBackgroundResource(ripple())
                setOnClickListener { row.onClick() }
            })
        }
    }

    private fun surface() = LinearLayout(requireContext()).apply {
        background = GradientDrawable().apply {
            setColor(Color.WHITE)
            cornerRadius = dp(16).toFloat()
        }
        clipToOutline = true
        elevation = dp(1).toFloat()
    }

    private fun sectionLabel(text: String) = TextView(requireContext()).apply {
        this.text = text
        textSize = 14f
        setTextColor(muted)
        setPadding(dp(4), dp(24), 0, dp(8))
    }

    private fun avatar(name: String) = TextView(requireContext()).apply {
        text = name.split(" ").filter { it.isNotBlank() }.take(2).joinToString("") { it.first().uppercase() }
        textSize = 20f
        setTypeface(typeface, Typeface.BOLD)
        setTextColor(Color.parseColor("#00736B"))
        gravity = Gravity.CENTER
        background = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(Color.parseColor("#D5EDE9"))
        }
        layoutParams = LinearLayout.LayoutParams(dp(56), dp(56))
    }

    private fun ripple() = TypedValue().also {
        requireContext().theme.resolveAttribute(android.R.attr.selectableItemBackground, it, true)
    }.resourceId

    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()

    private fun showLogoutConfirmation() {
        AlertDialog.Builder(requireContext())
            .setTitle(R.string.logout)
            .setMessage("Are you sure you want to logout?")
            .setPositiveButton(R.string.logout) { _, _ ->
                (activity as? MainActivity)?.logout()
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }
}
