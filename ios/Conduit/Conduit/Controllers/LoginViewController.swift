import UIKit
internal import WebKit
import GoogleSignIn

class LoginViewController: UIViewController {

    // UI Elements
    private let logoImageView = UIImageView()
    private let titleLabel = UILabel()
    private let communityLabel = UILabel()
    private let emailTextField = UITextField()
    private let passwordTextField = UITextField()
    private let loginButton = UIButton(type: .system)
    private let googleSignInButton = UIButton(type: .system)  // Changed to regular UIButton
    private let dividerLabel = UILabel()
    private let errorLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let switchCommunityButton = UIButton(type: .system)

    // Callback for successful login
    var onLoginSuccess: (() -> Void)?
    var onSwitchCommunity: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupActions()
        setupGoogleSignIn()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Hide navigation bar on login screen
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        // Logo/Icon
        logoImageView.image = UIImage(systemName: "building.2.fill")
        logoImageView.tintColor = .systemBlue
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false

        // Title
        titleLabel.text = "Conduit"
        titleLabel.font = .systemFont(ofSize: 32, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Community Name
        if let communityName = CommunityManager.shared.getCommunityName() {
            communityLabel.text = communityName
        } else {
            communityLabel.text = "Select a community"
        }
        communityLabel.font = .systemFont(ofSize: 16, weight: .medium)
        communityLabel.textColor = .secondaryLabel
        communityLabel.textAlignment = .center
        communityLabel.translatesAutoresizingMaskIntoConstraints = false

        // Email TextField
        emailTextField.placeholder = "Email"
        emailTextField.borderStyle = .roundedRect
        emailTextField.keyboardType = .emailAddress
        emailTextField.autocapitalizationType = .none
        emailTextField.autocorrectionType = .no
        emailTextField.textContentType = .emailAddress
        emailTextField.translatesAutoresizingMaskIntoConstraints = false

        // Password TextField
        passwordTextField.placeholder = "Password"
        passwordTextField.borderStyle = .roundedRect
        passwordTextField.isSecureTextEntry = true
        passwordTextField.textContentType = .password
        passwordTextField.translatesAutoresizingMaskIntoConstraints = false

        // Login Button
        loginButton.setTitle("Sign In", for: .normal)
        loginButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        loginButton.backgroundColor = .systemBlue
        loginButton.setTitleColor(.white, for: .normal)
        loginButton.layer.cornerRadius = 8
        loginButton.translatesAutoresizingMaskIntoConstraints = false

        // Divider
        dividerLabel.text = "OR"
        dividerLabel.textColor = .secondaryLabel
        dividerLabel.font = .systemFont(ofSize: 14)
        dividerLabel.textAlignment = .center
        dividerLabel.translatesAutoresizingMaskIntoConstraints = false

        // Google Sign-In Button (Custom)
        googleSignInButton.setTitle("  Sign in with Google", for: .normal)
        googleSignInButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        googleSignInButton.backgroundColor = .white
        googleSignInButton.setTitleColor(UIColor(red: 60/255, green: 64/255, blue: 67/255, alpha: 1), for: .normal)
        googleSignInButton.layer.cornerRadius = 4
        googleSignInButton.layer.borderWidth = 1
        googleSignInButton.layer.borderColor = UIColor(red: 218/255, green: 220/255, blue: 224/255, alpha: 1).cgColor
        googleSignInButton.translatesAutoresizingMaskIntoConstraints = false
        googleSignInButton.contentHorizontalAlignment = .center

        // Add shadow for elevation
        googleSignInButton.layer.shadowColor = UIColor.black.cgColor
        googleSignInButton.layer.shadowOffset = CGSize(width: 0, height: 1)
        googleSignInButton.layer.shadowOpacity = 0.1
        googleSignInButton.layer.shadowRadius = 2

        // We'll add the Google logo as a subview instead of using setImage
        setupGoogleLogo()

        // Error Label
        errorLabel.textColor = .systemRed
        errorLabel.font = .systemFont(ofSize: 14)
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        errorLabel.translatesAutoresizingMaskIntoConstraints = false

        // Activity Indicator
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false

        // Switch Community Button
        switchCommunityButton.setTitle("Switch Community", for: .normal)
        switchCommunityButton.titleLabel?.font = .systemFont(ofSize: 16)
        switchCommunityButton.setTitleColor(.systemBlue, for: .normal)
        switchCommunityButton.translatesAutoresizingMaskIntoConstraints = false

        // Add subviews
        view.addSubview(logoImageView)
        view.addSubview(titleLabel)
        view.addSubview(communityLabel)
        view.addSubview(emailTextField)
        view.addSubview(passwordTextField)
        view.addSubview(loginButton)
        view.addSubview(dividerLabel)
        view.addSubview(googleSignInButton)
        view.addSubview(errorLabel)
        view.addSubview(activityIndicator)
        view.addSubview(switchCommunityButton)
    }

    private func setupGoogleLogo() {
        // Use the official Google logo image
        let googleLogoImageView = UIImageView()
        googleLogoImageView.translatesAutoresizingMaskIntoConstraints = false
        googleLogoImageView.isUserInteractionEnabled = false
        googleLogoImageView.contentMode = .scaleAspectFit

        // Try to load the Google logo from assets
        if let googleLogo = UIImage(named: "google-logo") {
            googleLogoImageView.image = googleLogo
        } else {
            // Fallback: Create a simple "G" text logo with Google colors
            let label = UILabel(frame: CGRect(x: 0, y: 0, width: 18, height: 18))
            label.text = "G"
            label.font = .systemFont(ofSize: 15, weight: .medium)
            label.textColor = UIColor(red: 66/255, green: 133/255, blue: 244/255, alpha: 1) // Google Blue
            label.textAlignment = .center

            // Render the label as an image
            UIGraphicsBeginImageContextWithOptions(label.bounds.size, false, 0)
            if let context = UIGraphicsGetCurrentContext() {
                label.layer.render(in: context)
                googleLogoImageView.image = UIGraphicsGetImageFromCurrentImageContext()
            }
            UIGraphicsEndImageContext()
        }

        googleSignInButton.addSubview(googleLogoImageView)

        // Position the logo on the left side of the button
        NSLayoutConstraint.activate([
            googleLogoImageView.leadingAnchor.constraint(equalTo: googleSignInButton.leadingAnchor, constant: 16),
            googleLogoImageView.centerYAnchor.constraint(equalTo: googleSignInButton.centerYAnchor),
            googleLogoImageView.widthAnchor.constraint(equalToConstant: 18),
            googleLogoImageView.heightAnchor.constraint(equalToConstant: 18)
        ])
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Logo
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            logoImageView.widthAnchor.constraint(equalToConstant: 80),
            logoImageView.heightAnchor.constraint(equalToConstant: 80),

            // Title
            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            // Community Label
            communityLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            communityLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            communityLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            // Email TextField
            emailTextField.topAnchor.constraint(equalTo: communityLabel.bottomAnchor, constant: 40),
            emailTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emailTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            emailTextField.heightAnchor.constraint(equalToConstant: 50),

            // Password TextField
            passwordTextField.topAnchor.constraint(equalTo: emailTextField.bottomAnchor, constant: 16),
            passwordTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            passwordTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            passwordTextField.heightAnchor.constraint(equalToConstant: 50),

            // Error Label
            errorLabel.topAnchor.constraint(equalTo: passwordTextField.bottomAnchor, constant: 16),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            // Login Button
            loginButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 24),
            loginButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            loginButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            loginButton.heightAnchor.constraint(equalToConstant: 50),

            // Divider
            dividerLabel.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 20),
            dividerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Google Sign-In Button
            googleSignInButton.topAnchor.constraint(equalTo: dividerLabel.bottomAnchor, constant: 20),
            googleSignInButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            googleSignInButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            googleSignInButton.heightAnchor.constraint(equalToConstant: 50),

            // Activity Indicator
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: googleSignInButton.bottomAnchor, constant: 20),

            // Switch Community Button
            switchCommunityButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            switchCommunityButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    private func setupActions() {
        loginButton.addTarget(self, action: #selector(loginButtonTapped), for: .touchUpInside)

        // Add Google Sign-In button action HERE as well
        googleSignInButton.addTarget(self, action: #selector(googleSignInTapped), for: .touchUpInside)
        print("setupActions: Added googleSignInTapped action to button")

        // Switch Community button
        switchCommunityButton.addTarget(self, action: #selector(switchCommunityTapped), for: .touchUpInside)

        // Dismiss keyboard on tap
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)

        // Handle return key
        emailTextField.delegate = self
        passwordTextField.delegate = self
    }

    @objc private func switchCommunityTapped() {
        // Clear all auth data and community selection
        AuthenticationManager.shared.logout()
        CommunityManager.shared.clearCommunityURL()
        onSwitchCommunity?()
    }

    @objc private func loginButtonTapped() {
        guard let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty else {
            showError("Please enter both email and password")
            return
        }

        // Hide error and show loading
        errorLabel.isHidden = true
        activityIndicator.startAnimating()
        loginButton.isEnabled = false

        // Dismiss keyboard
        view.endEditing(true)

        // Perform login
        performLogin(email: email, password: password)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Google Sign-In

    private func setupGoogleSignIn() {
        // Configure Google Sign-In
        print("Setting up Google Sign-In...")

        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") else {
            print("ERROR: GoogleService-Info.plist not found in bundle")
            print("Bundle main path: \(Bundle.main.bundlePath)")
            googleSignInButton.isEnabled = false
            googleSignInButton.alpha = 0.5
            return
        }

        print("Found GoogleService-Info.plist at: \(path)")

        guard let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String,
              !clientId.contains("YOUR_IOS_CLIENT_ID") else {
            print("Warning: Google Sign-In not configured properly")
            googleSignInButton.isEnabled = false
            googleSignInButton.alpha = 0.5
            return
        }

        print("Configuring Google Sign-In with client ID: \(clientId)")

        // Create configuration
        let config = GIDConfiguration(clientID: clientId)
        GIDSignIn.sharedInstance.configuration = config

        // Verify configuration was set
        if GIDSignIn.sharedInstance.configuration == nil {
            print("ERROR: Failed to set GIDSignIn configuration!")
            googleSignInButton.isEnabled = false
            googleSignInButton.alpha = 0.5
            return
        }

        // Button action is added in setupActions()
        print("Google Sign-In configuration complete")
        print("Config: \(String(describing: config))")
        print("Button enabled: \(googleSignInButton.isEnabled)")
    }

    @objc private func googleSignInTapped() {
        print("=== Google Sign-In button tapped ===")
        print("Current configuration: \(String(describing: GIDSignIn.sharedInstance.configuration))")
        print("Presenting from: \(self)")
        print("Has window: \(self.view.window != nil)")
        print("Is presented: \(self.presentedViewController != nil)")

        // Make sure we're on the main thread
        guard Thread.isMainThread else {
            print("ERROR: Not on main thread!")
            DispatchQueue.main.async { [weak self] in
                self?.googleSignInTapped()
            }
            return
        }

        print("Calling GIDSignIn.sharedInstance.signIn...")

        GIDSignIn.sharedInstance.signIn(withPresenting: self) { [weak self] result, error in
            print("=== Google Sign-In callback received ===")

            if let error = error {
                print("Google Sign-In error: \(error)")
                print("Error code: \((error as NSError).code)")
                print("Error domain: \((error as NSError).domain)")
                print("Error userInfo: \((error as NSError).userInfo)")
                self?.showError("Google Sign-In failed: \(error.localizedDescription)")
                return
            }

            guard let result = result else {
                self?.showError("Google Sign-In was cancelled")
                return
            }

            // Get the user's ID token
            guard let idToken = result.user.idToken?.tokenString else {
                self?.showError("Failed to get Google ID token")
                return
            }

            // Send token to Rails backend
            self?.performGoogleLogin(idToken: idToken, user: result.user)
        }
    }

    private func performGoogleLogin(idToken: String, user: GIDGoogleUser) {
        // Show loading
        activityIndicator.startAnimating()
        googleSignInButton.isEnabled = false
        loginButton.isEnabled = false

        // Create request to Rails backend
        let googleAuthURL = AppConfig.baseURL.appendingPathComponent("api/v1/google_auth")

        var request = URLRequest(url: googleAuthURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Create body with Google user info
        let email = user.profile?.email ?? ""
        let name = user.profile?.name ?? ""

        print("Google Sign-In - Email: \(email)")
        print("Google Sign-In - Name: \(name)")

        // Include community domain to scope login
        let communityDomain = CommunityManager.shared.getCommunityDomain() ?? ""
        let body: [String: Any] = [
            "id_token": idToken,
            "email": email,
            "name": name,
            "image_url": user.profile?.imageURL(withDimension: 200)?.absoluteString ?? "",
            "community_domain": communityDomain
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            showError("Failed to prepare Google login request")
            activityIndicator.stopAnimating()
            googleSignInButton.isEnabled = true
            loginButton.isEnabled = true
            return
        }

        // Send request
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                self?.googleSignInButton.isEnabled = true
                self?.loginButton.isEnabled = true

                if let error = error {
                    self?.showError("Network error: \(error.localizedDescription)")
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    self?.showError("Invalid response from server")
                    return
                }

                if httpResponse.statusCode == 200 {
                    // Success - save auth token and cookies, then proceed
                    self?.handleLoginSuccess(response: httpResponse, data: data)
                } else {
                    // Try to parse error message
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let error = json["error"] as? String {
                        self?.showError(error)
                    } else {
                        self?.showError("Google authentication failed")
                    }
                }
            }
        }.resume()
    }

    private func performLogin(email: String, password: String) {
        // Create login URL
        let loginURL = AppConfig.baseURL.appendingPathComponent("api/v1/login")

        // Create request
        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Create body - include community domain to scope login
        let communityDomain = CommunityManager.shared.getCommunityDomain() ?? ""
        let body: [String: Any] = [
            "email": email,
            "password": password,
            "mobile": true,
            "community_domain": communityDomain
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            showError("Failed to prepare login request")
            return
        }

        // Perform request
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                self?.loginButton.isEnabled = true

                if let error = error {
                    self?.showError("Network error: \(error.localizedDescription)")
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    self?.showError("Invalid response from server")
                    return
                }

                if httpResponse.statusCode == 200 {
                    // Success - save auth token and cookies, then proceed
                    self?.handleLoginSuccess(response: httpResponse, data: data)
                } else if httpResponse.statusCode == 401 {
                    self?.showError("Invalid email or password")
                } else {
                    // Try to parse error message
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let error = json["error"] as? String {
                        self?.showError(error)
                    } else {
                        self?.showError("Login failed. Please try again.")
                    }
                }
            }
        }.resume()
    }

    private func handleLoginSuccess(response: HTTPURLResponse, data: Data?) {
        // Parse and store auth token from response
        if let data = data,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let authToken = json["auth_token"] as? String {
                let userId = (json["user"] as? [String: Any])?["id"] as? Int
                AuthenticationManager.shared.storeAuthToken(authToken, userId: userId)
                print("Stored auth token from login response")
            }
        }

        // Save cookies to HTTPCookieStorage
        if let cookies = HTTPCookieStorage.shared.cookies(for: response.url!) {
            for cookie in cookies {
                HTTPCookieStorage.shared.setCookie(cookie)
                print("Saved cookie: \(cookie.name) for domain: \(cookie.domain)")
            }
        }

        // IMPORTANT: Clear ALL existing WebView data first, then set new cookies
        // This ensures no stale data from previous community sessions
        let dataStore = WKWebsiteDataStore.default()
        let allTypes = WKWebsiteDataStore.allWebsiteDataTypes()

        dataStore.removeData(ofTypes: allTypes, modifiedSince: Date.distantPast) { [weak self] in
            print("Cleared all WebView data before setting new session")

            // Now sync the new cookies from HTTPCookieStorage to WebView
            let cookies = HTTPCookieStorage.shared.cookies ?? []
            let group = DispatchGroup()

            for cookie in cookies {
                group.enter()
                dataStore.httpCookieStore.setCookie(cookie) {
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                print("Synced \(cookies.count) cookies to WebView after clearing")
                self?.onLoginSuccess?()
            }
        }
    }

    private func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false

        // Shake animation for error feedback
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 0.6
        animation.values = [-20, 20, -20, 20, -10, 10, -5, 5, 0]
        errorLabel.layer.add(animation, forKey: "shake")
    }
}

// MARK: - UITextFieldDelegate
extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == emailTextField {
            passwordTextField.becomeFirstResponder()
        } else if textField == passwordTextField {
            loginButtonTapped()
        }
        return true
    }
}

// MARK: - Google Logo View
class GoogleLogoView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        let size = min(rect.width, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = size / 2

        // Google colors
        let googleBlue = UIColor(red: 66/255, green: 133/255, blue: 244/255, alpha: 1)
        let googleRed = UIColor(red: 234/255, green: 67/255, blue: 53/255, alpha: 1)
        let googleYellow = UIColor(red: 251/255, green: 188/255, blue: 5/255, alpha: 1)
        let googleGreen = UIColor(red: 52/255, green: 168/255, blue: 83/255, alpha: 1)

        // Draw the "G" shape using the Google colors
        // This is a simplified version - for production, use the actual Google logo image

        // Blue section (top right)
        context.setFillColor(googleBlue.cgColor)
        context.move(to: center)
        context.addArc(center: center, radius: radius, startAngle: -CGFloat.pi/4, endAngle: CGFloat.pi/4, clockwise: false)
        context.closePath()
        context.fillPath()

        // Green section (bottom right)
        context.setFillColor(googleGreen.cgColor)
        context.move(to: center)
        context.addArc(center: center, radius: radius, startAngle: CGFloat.pi/4, endAngle: 3*CGFloat.pi/4, clockwise: false)
        context.closePath()
        context.fillPath()

        // Yellow section (bottom left)
        context.setFillColor(googleYellow.cgColor)
        context.move(to: center)
        context.addArc(center: center, radius: radius, startAngle: 3*CGFloat.pi/4, endAngle: 5*CGFloat.pi/4, clockwise: false)
        context.closePath()
        context.fillPath()

        // Red section (top left)
        context.setFillColor(googleRed.cgColor)
        context.move(to: center)
        context.addArc(center: center, radius: radius, startAngle: 5*CGFloat.pi/4, endAngle: 7*CGFloat.pi/4, clockwise: false)
        context.closePath()
        context.fillPath()

        // Draw white center and "G" bar
        context.setFillColor(UIColor.white.cgColor)
        let innerRadius = radius * 0.5
        context.fillEllipse(in: CGRect(x: center.x - innerRadius, y: center.y - innerRadius,
                                       width: innerRadius * 2, height: innerRadius * 2))

        // Draw the horizontal bar of the "G"
        context.setFillColor(googleBlue.cgColor)
        let barHeight = radius * 0.2
        let barWidth = radius * 0.5
        context.fill(CGRect(x: center.x, y: center.y - barHeight/2,
                           width: barWidth, height: barHeight))
    }
}
