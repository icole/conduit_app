import UIKit

/// Data model for a community from the API
struct Community: Codable {
    let id: Int
    let name: String
    let domain: String
    let slug: String
}

/// View controller for selecting a community before login
class CommunitySelectViewController: UIViewController {

    // MARK: - Properties

    var onCommunitySelected: (() -> Void)?

    private var communities: [Community] = []
    private var selectedCommunity: Community?

    // MARK: - UI Elements

    private let logoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: "AppIcon")
        imageView.layer.cornerRadius = 20
        imageView.clipsToBounds = true
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Select Your Community"
        label.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        label.textAlignment = .center
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Choose the community you belong to"
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()

    private let tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.register(UITableViewCell.self, forCellReuseIdentifier: "CommunityCell")
        return table
    }()

    private let continueButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Continue", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.isEnabled = false
        button.alpha = 0.5
        return button
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private let errorLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .systemRed
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        fetchCommunities()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.prefersLargeTitles = false

        view.addSubview(logoImageView)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(tableView)
        view.addSubview(continueButton)
        view.addSubview(activityIndicator)
        view.addSubview(errorLabel)

        tableView.delegate = self
        tableView.dataSource = self

        continueButton.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            logoImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 80),
            logoImageView.heightAnchor.constraint(equalToConstant: 80),

            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            errorLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            tableView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: continueButton.topAnchor, constant: -20),

            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            continueButton.heightAnchor.constraint(equalToConstant: 50),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // MARK: - API

    private func fetchCommunities() {
        activityIndicator.startAnimating()
        tableView.isHidden = true
        errorLabel.isHidden = true

        let apiURL = URL(string: "https://api.conduitcoho.app/api/v1/communities")!

        URLSession.shared.dataTask(with: apiURL) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                self?.tableView.isHidden = false

                if let error = error {
                    self?.showError("Failed to load communities: \(error.localizedDescription)")
                    return
                }

                guard let data = data else {
                    self?.showError("No data received")
                    return
                }

                do {
                    let communities = try JSONDecoder().decode([Community].self, from: data)
                    self?.communities = communities
                    self?.tableView.reloadData()

                    if communities.isEmpty {
                        self?.showError("No communities available")
                    }
                } catch {
                    self?.showError("Failed to parse communities: \(error.localizedDescription)")
                }
            }
        }.resume()
    }

    private func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
    }

    // MARK: - Actions

    @objc private func continueButtonTapped() {
        guard let community = selectedCommunity else { return }

        // Build the full URL with https://
        let urlString = "https://\(community.domain)"
        guard let url = URL(string: urlString) else {
            showError("Invalid community URL")
            return
        }

        // Save the selected community
        CommunityManager.shared.setCommunityURL(url)
        CommunityManager.shared.setCommunityName(community.name)

        print("Selected community: \(community.name) at \(url.absoluteString)")

        onCommunitySelected?()
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource

extension CommunitySelectViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return communities.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CommunityCell", for: indexPath)
        let community = communities[indexPath.row]

        var content = cell.defaultContentConfiguration()
        content.text = community.name
        content.secondaryText = community.domain
        cell.contentConfiguration = content

        // Show checkmark for selected community
        if selectedCommunity?.id == community.id {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        selectedCommunity = communities[indexPath.row]
        tableView.reloadData()

        // Enable continue button
        continueButton.isEnabled = true
        continueButton.alpha = 1.0
    }
}
