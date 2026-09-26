package com.colecoding.conduit.chat

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.LinearLayout
import androidx.appcompat.app.AppCompatActivity
import com.colecoding.conduit.ui.padForSystemBars
import io.getstream.chat.android.client.ChatClient
import io.getstream.chat.android.models.Filters
import io.getstream.chat.android.models.SearchMessagesResult
import io.getstream.chat.android.ui.common.model.MessageResult
import io.getstream.chat.android.ui.feature.search.SearchInputView
import io.getstream.chat.android.ui.feature.search.list.SearchResultListView
import io.getstream.result.call.Call

/**
 * Searches the messages of one channel. Stream's UI kit only searches across
 * every channel, so this reuses its search box and result list with a
 * searchMessages query limited to [EXTRA_CID]. Picking a result reopens the
 * channel scrolled to that message.
 */
class ChannelSearchActivity : AppCompatActivity() {

    companion object {
        private const val EXTRA_CID = "extra_cid"
        private const val PAGE_SIZE = 30

        fun createIntent(context: Context, cid: String): Intent =
            Intent(context, ChannelSearchActivity::class.java).putExtra(EXTRA_CID, cid)
    }

    private lateinit var cid: String
    private lateinit var resultsView: SearchResultListView

    private var query = ""
    private var next: String? = null
    private val results = mutableListOf<MessageResult>()
    private var searchCall: Call<SearchMessagesResult>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        cid = intent.getStringExtra(EXTRA_CID) ?: run {
            finish()
            return
        }

        val searchInput = SearchInputView(this)
        resultsView = SearchResultListView(this)
        val margin = (8 * resources.displayMetrics.density).toInt()
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            addView(searchInput, LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { setMargins(margin, margin, margin, margin) })
            addView(resultsView, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f))
        }
        setContentView(column)
        column.padForSystemBars()

        searchInput.setDebouncedInputChangedListener { search(it) }
        searchInput.setSearchStartedListener { search(it) }
        resultsView.setLoadMoreListener { if (next != null) fetchPage() }
        resultsView.setSearchResultSelectedListener { message ->
            // Back to the channel (it's under this screen), scrolled to the match
            startActivity(
                TrackingMessageListActivity.createIntent(this, cid, message.id)
                    .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            )
            finish()
        }
    }

    override fun onDestroy() {
        searchCall?.cancel()
        super.onDestroy()
    }

    private fun search(text: String) {
        searchCall?.cancel()
        query = text.trim()
        next = null
        results.clear()
        if (query.isEmpty()) {
            resultsView.showMessages(query, emptyList())
            return
        }
        resultsView.showLoading()
        fetchPage()
    }

    private fun fetchPage() {
        val searchedFor = query
        val call = ChatClient.instance().searchMessages(
            channelFilter = Filters.eq("cid", cid),
            messageFilter = Filters.autocomplete("text", searchedFor),
            limit = PAGE_SIZE,
            next = next,
        )
        searchCall = call
        call.enqueue { result ->
            if (searchedFor != query || isFinishing) return@enqueue
            val page = result.getOrNull()
            if (page == null) {
                resultsView.showError()
                return@enqueue
            }
            next = page.next
            results += page.messages.map { MessageResult(it, null) }
            resultsView.showMessages(searchedFor, results.toList())
            resultsView.setPaginationEnabled(page.next != null)
        }
    }
}
