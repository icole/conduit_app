import UIKit
import StreamChat

/// Searches the messages of one channel. Stream's UI kit only searches across
/// every channel, so this runs a MessageSearchQuery limited to the channel's
/// cid. Picking a result closes the screen and calls `onSelect` with the
/// message id, so the channel can jump to it.
final class ChannelMessageSearchVC: UITableViewController, UISearchResultsUpdating {
    var onSelect: ((MessageId) -> Void)?

    private let cid: ChannelId
    private let messageSearch: ChatMessageSearchController
    private let searchBarController = UISearchController(searchResultsController: nil)
    private var results: [ChatMessage] = []
    private var currentTerm = ""
    private var pendingSearch: DispatchWorkItem?
    private var isLoadingMore = false
    private var hasMore = false

    private static let pageSize = 30
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    init(cid: ChannelId, client: ChatClient) {
        self.cid = cid
        self.messageSearch = client.messageSearchController()
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Search this chat"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(close))

        searchBarController.searchResultsUpdater = self
        searchBarController.obscuresBackgroundDuringPresentation = false
        searchBarController.searchBar.placeholder = "Search messages"
        navigationItem.searchController = searchBarController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true

        tableView.keyboardDismissMode = .onDrag
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.async { [weak self] in
            self?.searchBarController.searchBar.becomeFirstResponder()
        }
    }

    @objc private func close() {
        dismiss(animated: true)
    }

    // MARK: - Searching

    func updateSearchResults(for searchController: UISearchController) {
        let term = (searchController.searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard term != currentTerm else { return }

        // Wait for a pause in typing before searching
        pendingSearch?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.search(term) }
        pendingSearch = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func search(_ term: String) {
        currentTerm = term
        guard !term.isEmpty else {
            show([], hasMore: false)
            return
        }

        let query = MessageSearchQuery(
            channelFilter: .equal(.cid, to: cid),
            messageFilter: .autocomplete(.text, text: term),
            pageSize: Self.pageSize
        )
        messageSearch.search(query: query) { [weak self] error in
            guard let self = self, term == self.currentTerm else { return }
            let found = Array(self.messageSearch.messages)
            self.show(found, hasMore: error == nil && found.count >= Self.pageSize, failed: error != nil)
        }
    }

    private func loadMore() {
        guard hasMore, !isLoadingMore, !currentTerm.isEmpty else { return }
        isLoadingMore = true
        let term = currentTerm
        let before = results.count
        messageSearch.loadNextMessages(limit: Self.pageSize) { [weak self] error in
            guard let self = self else { return }
            self.isLoadingMore = false
            guard term == self.currentTerm, error == nil else { return }
            let found = Array(self.messageSearch.messages)
            self.show(found, hasMore: found.count > before)
        }
    }

    private func show(_ messages: [ChatMessage], hasMore: Bool, failed: Bool = false) {
        results = messages
        self.hasMore = hasMore
        tableView.reloadData()

        if failed {
            tableView.backgroundView = emptyLabel("Search isn't working right now. Try again in a moment.")
        } else if messages.isEmpty && !currentTerm.isEmpty {
            tableView.backgroundView = emptyLabel("No messages in this chat match “\(currentTerm)”.")
        } else {
            tableView.backgroundView = nil
        }
    }

    private func emptyLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
        return label
    }

    // MARK: - Table

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        results.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "result")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "result")
        let message = results[indexPath.row]

        var content = cell.defaultContentConfiguration()
        content.text = message.text
        content.textProperties.numberOfLines = 3
        let author = message.author.name ?? message.author.id
        content.secondaryText = "\(author) · \(Self.dateFormatter.string(from: message.createdAt))"
        content.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row >= results.count - 5 {
            loadMore()
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let messageId = results[indexPath.row].id
        let onSelect = self.onSelect
        dismiss(animated: true) {
            onSelect?(messageId)
        }
    }
}
