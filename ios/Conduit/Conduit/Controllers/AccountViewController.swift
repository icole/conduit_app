import UIKit

class AccountViewController: UIViewController {

    // Callbacks
    var onLogout: (() -> Void)?
    var onSwitchCommunity: (() -> Void)?

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    private enum Section: Int, CaseIterable {
        case account
        case community
    }

    private enum AccountRow: Int, CaseIterable {
        case logout
    }

    private enum CommunityRow: Int, CaseIterable {
        case switchCommunity
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Account"
        view.backgroundColor = .systemGroupedBackground

        setupTableView()
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func showLogoutConfirmation() {
        let alert = UIAlertController(
            title: "Logout",
            message: "Are you sure you want to logout?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Logout", style: .destructive) { [weak self] _ in
            self?.onLogout?()
        })

        present(alert, animated: true)
    }

    private func showSwitchCommunityConfirmation() {
        let alert = UIAlertController(
            title: "Switch Community",
            message: "This will log you out and return to the community selection screen. Continue?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Continue", style: .default) { [weak self] _ in
            self?.onSwitchCommunity?()
        })

        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension AccountViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }

        switch sectionType {
        case .account:
            return AccountRow.allCases.count
        case .community:
            return CommunityRow.allCases.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.accessoryType = .disclosureIndicator

        guard let section = Section(rawValue: indexPath.section) else { return cell }

        switch section {
        case .account:
            if let row = AccountRow(rawValue: indexPath.row) {
                switch row {
                case .logout:
                    cell.textLabel?.text = "Logout"
                    cell.textLabel?.textColor = .systemRed
                    cell.accessoryType = .none
                }
            }
        case .community:
            if let row = CommunityRow(rawValue: indexPath.row) {
                switch row {
                case .switchCommunity:
                    cell.textLabel?.text = "Switch Community"
                    cell.textLabel?.textColor = .label
                }
            }
        }

        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sectionType = Section(rawValue: section) else { return nil }

        switch sectionType {
        case .account:
            return "Account"
        case .community:
            return "Community"
        }
    }
}

// MARK: - UITableViewDelegate
extension AccountViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let section = Section(rawValue: indexPath.section) else { return }

        switch section {
        case .account:
            if let row = AccountRow(rawValue: indexPath.row) {
                switch row {
                case .logout:
                    showLogoutConfirmation()
                }
            }
        case .community:
            if let row = CommunityRow(rawValue: indexPath.row) {
                switch row {
                case .switchCommunity:
                    showSwitchCommunityConfirmation()
                }
            }
        }
    }
}
