import SafariServices
import UIKit

/// Data model for a community from the API
struct Community: Codable {
    let id: Int
    let name: String
    let domain: String
    let slug: String
    /// "pending", "active", or nil from older servers
    let status: String?

    var isPending: Bool { status == "pending" }
}

/// Asks for the community by name and looks up that one community, rather than
/// listing every community on the server.
class CommunitySelectViewController: UIViewController {

    // MARK: - Properties

    var onCommunitySelected: (() -> Void)?

    private var foundCommunity: Community?

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
        label.text = "Find Your Community"
        label.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        label.textAlignment = .center
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Enter the name your community uses on Conduit"
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let communityTextField: UITextField = {
        let field = UITextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.placeholder = "Community name"
        field.borderStyle = .roundedRect
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.clearButtonMode = .whileEditing
        field.returnKeyType = .search
        field.font = UIFont.systemFont(ofSize: 17)
        return field
    }()

    private let findButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Find community", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.systemBlue.cgColor
        return button
    }()

    private let foundLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        return label
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

    private let signupButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Start a new community", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        return button
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
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
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.prefersLargeTitles = false

        [ logoImageView, titleLabel, subtitleLabel, communityTextField, findButton,
          foundLabel, errorLabel, activityIndicator, signupButton, continueButton ].forEach { view.addSubview($0) }

        communityTextField.delegate = self
        communityTextField.addTarget(self, action: #selector(queryChanged), for: .editingChanged)
        findButton.addTarget(self, action: #selector(findButtonTapped), for: .touchUpInside)
        continueButton.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        signupButton.addTarget(self, action: #selector(signupButtonTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            logoImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 80),
            logoImageView.heightAnchor.constraint(equalToConstant: 80),

            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            communityTextField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 32),
            communityTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            communityTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            communityTextField.heightAnchor.constraint(equalToConstant: 48),

            findButton.topAnchor.constraint(equalTo: communityTextField.bottomAnchor, constant: 12),
            findButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            findButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            findButton.heightAnchor.constraint(equalToConstant: 48),

            activityIndicator.topAnchor.constraint(equalTo: findButton.bottomAnchor, constant: 20),
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            foundLabel.topAnchor.constraint(equalTo: findButton.bottomAnchor, constant: 20),
            foundLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            foundLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            errorLabel.topAnchor.constraint(equalTo: findButton.bottomAnchor, constant: 20),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            signupButton.bottomAnchor.constraint(equalTo: continueButton.topAnchor, constant: -8),
            signupButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            continueButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    // MARK: - Lookup

    /// The lookup endpoint for what was typed, or nil if it was blank.
    private func lookupURL(for query: String) -> URL? {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }

        var components = URLComponents(
            url: AppConfig.baseURL.appendingPathComponent("api/v1/communities/lookup"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [ URLQueryItem(name: "slug", value: normalized) ]
        return components?.url
    }

    @objc private func findButtonTapped() {
        communityTextField.resignFirstResponder()

        guard let url = lookupURL(for: communityTextField.text ?? "") else {
            showError("Enter your community's name.")
            return
        }

        clearResult()
        activityIndicator.startAnimating()
        findButton.isEnabled = false

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.activityIndicator.stopAnimating()
                self.findButton.isEnabled = true

                if error != nil {
                    self.showError("Couldn't reach Conduit. Check your connection and try again.")
                    return
                }

                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                if statusCode == 404 {
                    self.showError("We couldn't find a community with that name. Check the spelling, or ask an admin for the name they use.")
                    return
                }

                guard statusCode == 200, let data = data,
                      let community = try? JSONDecoder().decode(Community.self, from: data) else {
                    self.showError("Couldn't reach Conduit. Check your connection and try again.")
                    return
                }

                self.showFound(community)
            }
        }.resume()
    }

    private func showFound(_ community: Community) {
        foundCommunity = community
        foundLabel.text = community.isPending
            ? "\(community.name)\nAwaiting approval — chat unlocks once it's approved."
            : community.name
        foundLabel.isHidden = false
        continueButton.isEnabled = true
        continueButton.alpha = 1.0
    }

    private func clearResult() {
        foundCommunity = nil
        foundLabel.isHidden = true
        errorLabel.isHidden = true
        continueButton.isEnabled = false
        continueButton.alpha = 0.5
    }

    private func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
    }

    // MARK: - Actions

    @objc private func queryChanged() {
        // Typing again invalidates the previous result
        if foundCommunity != nil || !errorLabel.isHidden {
            clearResult()
        }
    }

    @objc private func signupButtonTapped() {
        let url = AppConfig.baseURL.appendingPathComponent("communities/new")
        let safari = SFSafariViewController(url: url)
        present(safari, animated: true)
    }

    @objc private func continueButtonTapped() {
        guard let community = foundCommunity else { return }

        // Debug builds talk to the local server; release builds use the community's domain
        let url: URL
        switch AppConfig.Environment.current {
        case .development:
            url = AppConfig.baseURL
        case .production:
            guard let productionURL = URL(string: "https://\(community.domain)") else {
                showError("That community's address looks invalid.")
                return
            }
            url = productionURL
        }

        CommunityManager.shared.setCommunityURL(url)
        CommunityManager.shared.setCommunityName(community.name)
        CommunityManager.shared.setCommunityDomain(community.domain)

        print("Selected community: \(community.name) at \(url.absoluteString) (domain: \(community.domain))")

        onCommunitySelected?()
    }
}

// MARK: - UITextFieldDelegate

extension CommunitySelectViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        findButtonTapped()
        return true
    }
}
