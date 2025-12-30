import UIKit

class AccountViewController: UIViewController {

    // Callbacks
    var onLogout: (() -> Void)?

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    private enum AccountRow: Int, CaseIterable {
        case logout
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
}

// MARK: - UITableViewDataSource
extension AccountViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return AccountRow.allCases.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        if let row = AccountRow(rawValue: indexPath.row) {
            switch row {
            case .logout:
                cell.textLabel?.text = "Logout"
                cell.textLabel?.textColor = .systemRed
                cell.accessoryType = .none
            }
        }

        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Account"
    }
}

// MARK: - UITableViewDelegate
extension AccountViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if let row = AccountRow(rawValue: indexPath.row) {
            switch row {
            case .logout:
                showLogoutConfirmation()
            }
        }
    }
}
