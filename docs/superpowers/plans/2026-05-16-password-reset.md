# Password Reset Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow users to reset their forgotten password via an email-based flow, accessible from mobile login screens and triggerable by admins.

**Architecture:** Stateless JWT token (1-hour expiry) encodes user_id + purpose. A `password_reset_sent_at` column on User enforces single-use. Web-based reset pages use existing Tailwind/DaisyUI styling. Mobile apps open the reset page in the system browser.

**Tech Stack:** Rails 8, JwtService (existing), ActionMailer + Resend, Minitest, Swift (iOS), Kotlin (Android)

---

### Task 1: Migration — Add password_reset_sent_at to users

**Files:**
- Create: `db/migrate/XXXXXX_add_password_reset_sent_at_to_users.rb`

- [ ] **Step 1: Generate migration**

Run:
```bash
bin/rails generate migration AddPasswordResetSentAtToUsers password_reset_sent_at:datetime
```

- [ ] **Step 2: Run migration**

Run:
```bash
bin/rails db:migrate
```

- [ ] **Step 3: Verify schema**

Run:
```bash
grep password_reset_sent_at db/schema.rb
```
Expected: `t.datetime "password_reset_sent_at"`

- [ ] **Step 4: Commit**

```bash
git add db/migrate/*_add_password_reset_sent_at_to_users.rb db/schema.rb
git commit -m "Add password_reset_sent_at column to users"
```

---

### Task 2: JwtService — Add password reset token methods

**Files:**
- Modify: `app/services/jwt_service.rb`
- Create: `test/services/jwt_service_test.rb`

- [ ] **Step 1: Write failing tests**

Create `test/services/jwt_service_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class JwtServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:email_user)
  end

  test "generate_password_reset_token creates a valid token" do
    token = JwtService.generate_password_reset_token(@user)
    assert token.present?

    decoded = JwtService.decode(token)
    assert_equal @user.id, decoded[:user_id]
    assert_equal @user.community_id, decoded[:community_id]
    assert_equal "password_reset", decoded[:type]
    assert decoded[:exp].present?
    assert decoded[:iat].present?
  end

  test "verify_password_reset_token returns user for valid token" do
    @user.update!(password_reset_sent_at: Time.current)
    token = JwtService.generate_password_reset_token(@user)

    result = JwtService.verify_password_reset_token(token)
    assert_equal @user, result
  end

  test "verify_password_reset_token returns nil for expired token" do
    @user.update!(password_reset_sent_at: 2.hours.ago)
    token = JwtService.encode(
      { user_id: @user.id, community_id: @user.community_id, type: "password_reset" },
      -1.hour
    )

    result = JwtService.verify_password_reset_token(token)
    assert_nil result
  end

  test "verify_password_reset_token returns nil for wrong type" do
    token = JwtService.generate_auth_token(@user)

    result = JwtService.verify_password_reset_token(token)
    assert_nil result
  end

  test "verify_password_reset_token returns nil if password_reset_sent_at is nil (already used)" do
    @user.update!(password_reset_sent_at: nil)
    token = JwtService.generate_password_reset_token(@user)

    result = JwtService.verify_password_reset_token(token)
    assert_nil result
  end

  test "verify_password_reset_token returns nil if token issued before password_reset_sent_at" do
    # Simulate: token was issued, then a NEW reset was requested (invalidating old token)
    old_time = 2.hours.ago
    token = JwtService.encode(
      { user_id: @user.id, community_id: @user.community_id, type: "password_reset", iat: old_time.to_i },
      1.hour
    )
    @user.update!(password_reset_sent_at: Time.current)

    result = JwtService.verify_password_reset_token(token)
    assert_nil result
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
bin/rails test test/services/jwt_service_test.rb
```
Expected: FAIL — `generate_password_reset_token` and `verify_password_reset_token` not defined.

- [ ] **Step 3: Implement the methods**

Add to `app/services/jwt_service.rb` inside the `class << self` block, after `verify_auth_token`:

```ruby
    def generate_password_reset_token(user)
      payload = {
        user_id: user.id,
        community_id: user.community_id,
        type: "password_reset"
      }
      encode(payload, 1.hour)
    end

    def verify_password_reset_token(token)
      decoded = decode(token)
      return nil unless decoded && decoded[:type] == "password_reset"

      community = Community.find_by(id: decoded[:community_id])
      return nil unless community

      user = ActsAsTenant.with_tenant(community) do
        User.find_by(id: decoded[:user_id])
      end
      return nil unless user

      # Single-use check: token must have been issued at or after password_reset_sent_at
      return nil if user.password_reset_sent_at.nil?
      return nil if decoded[:iat].to_i < user.password_reset_sent_at.to_i

      user
    rescue StandardError => e
      Rails.logger.error "Password reset token verification error: #{e.message}"
      nil
    end
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
bin/rails test test/services/jwt_service_test.rb
```
Expected: All pass.

- [ ] **Step 5: Commit**

```bash
git add app/services/jwt_service.rb test/services/jwt_service_test.rb
git commit -m "Add password reset token generation and verification to JwtService"
```

---

### Task 3: UserMailer — Password reset email

**Files:**
- Create: `app/mailers/user_mailer.rb`
- Create: `app/views/user_mailer/password_reset.html.erb`
- Create: `test/mailers/user_mailer_test.rb`

- [ ] **Step 1: Write failing test**

Create `test/mailers/user_mailer_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  setup do
    @user = users(:email_user)
    @token = "test_token_abc123"
    ActsAsTenant.current_tenant = communities(:crow_woods)
  end

  test "password_reset sends email to user with reset link" do
    email = UserMailer.password_reset(@user, @token)

    assert_equal ["emailuser@example.com"], email.to
    assert_equal "Reset your password", email.subject
    assert_match "password_reset/edit", email.body.encoded
    assert_match @token, email.body.encoded
  end

  test "password_reset email contains user name" do
    email = UserMailer.password_reset(@user, @token)

    assert_match @user.name, email.body.encoded
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
bin/rails test test/mailers/user_mailer_test.rb
```
Expected: FAIL — `UserMailer` not defined or missing method.

- [ ] **Step 3: Create the mailer**

Create `app/mailers/user_mailer.rb`:

```ruby
# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def password_reset(user, token)
    @user = user
    @token = token
    @reset_url = password_reset_edit_url(token: @token)

    mail(to: @user.email, subject: "Reset your password")
  end
end
```

- [ ] **Step 4: Create the email template**

Create `app/views/user_mailer/password_reset.html.erb`:

```erb
<h2>Reset your password</h2>

<p>Hi <%= @user.name %>,</p>

<p>We received a request to reset your password. Click the link below to choose a new one:</p>

<p><a href="<%= @reset_url %>">Reset my password</a></p>

<p>This link will expire in 1 hour. If you didn't request this, you can safely ignore this email.</p>

<p>Thanks,<br>The Conduit Team</p>
```

- [ ] **Step 5: Run tests to verify they pass**

Run:
```bash
bin/rails test test/mailers/user_mailer_test.rb
```
Expected: All pass.

- [ ] **Step 6: Commit**

```bash
git add app/mailers/user_mailer.rb app/views/user_mailer/password_reset.html.erb test/mailers/user_mailer_test.rb
git commit -m "Add UserMailer with password_reset email"
```

---

### Task 4: PasswordResetsController — Request and reset flow

**Files:**
- Create: `app/controllers/password_resets_controller.rb`
- Create: `app/views/password_resets/new.html.erb`
- Create: `app/views/password_resets/edit.html.erb`
- Create: `test/controllers/password_resets_controller_test.rb`

- [ ] **Step 1: Write failing tests**

Create `test/controllers/password_resets_controller_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class PasswordResetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:email_user)
    @community = communities(:crow_woods)
    host! @community.domain || "example.com"
  end

  # GET /password_reset/new
  test "new renders the request form" do
    get password_reset_new_path
    assert_response :success
    assert_select "input[name='email']"
  end

  # POST /password_reset
  test "create sends reset email for existing user" do
    assert_emails 1 do
      post password_reset_path, params: { email: @user.email }
    end
    assert_redirected_to password_reset_new_path
    assert_match(/instructions/, flash[:notice])
    @user.reload
    assert @user.password_reset_sent_at.present?
  end

  test "create shows same message for non-existent email (no enumeration)" do
    assert_no_emails do
      post password_reset_path, params: { email: "nobody@example.com" }
    end
    assert_redirected_to password_reset_new_path
    assert_match(/instructions/, flash[:notice])
  end

  # GET /password_reset/edit
  test "edit renders the reset form for valid token" do
    @user.update!(password_reset_sent_at: Time.current)
    token = JwtService.generate_password_reset_token(@user)

    get password_reset_edit_path(token: token)
    assert_response :success
    assert_select "input[name='password']"
    assert_select "input[name='password_confirmation']"
  end

  test "edit shows error for invalid token" do
    get password_reset_edit_path(token: "invalid_token")
    assert_redirected_to password_reset_new_path
    assert_match(/expired|invalid/i, flash[:alert])
  end

  test "edit shows error for expired token" do
    @user.update!(password_reset_sent_at: 2.hours.ago)
    token = JwtService.encode(
      { user_id: @user.id, community_id: @user.community_id, type: "password_reset" },
      -1.second
    )

    get password_reset_edit_path(token: token)
    assert_redirected_to password_reset_new_path
    assert_match(/expired|invalid/i, flash[:alert])
  end

  # PATCH /password_reset
  test "update changes password with valid token" do
    @user.update!(password_reset_sent_at: Time.current)
    token = JwtService.generate_password_reset_token(@user)

    patch password_reset_path, params: {
      token: token,
      password: "newpassword123",
      password_confirmation: "newpassword123"
    }

    assert_redirected_to login_path
    assert_match(/updated/, flash[:notice])
    @user.reload
    assert @user.authenticate("newpassword123")
    assert_nil @user.password_reset_sent_at
  end

  test "update fails with mismatched passwords" do
    @user.update!(password_reset_sent_at: Time.current)
    token = JwtService.generate_password_reset_token(@user)

    patch password_reset_path, params: {
      token: token,
      password: "newpassword123",
      password_confirmation: "different"
    }

    assert_response :unprocessable_entity
    @user.reload
    assert @user.authenticate("testpassword123") # unchanged
  end

  test "update fails with invalid token" do
    patch password_reset_path, params: {
      token: "invalid",
      password: "newpassword123",
      password_confirmation: "newpassword123"
    }

    assert_redirected_to password_reset_new_path
    assert_match(/expired|invalid/i, flash[:alert])
  end

  test "update fails with too-short password" do
    @user.update!(password_reset_sent_at: Time.current)
    token = JwtService.generate_password_reset_token(@user)

    patch password_reset_path, params: {
      token: token,
      password: "short",
      password_confirmation: "short"
    }

    assert_response :unprocessable_entity
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
bin/rails test test/controllers/password_resets_controller_test.rb
```
Expected: FAIL — routing error (no route matches).

- [ ] **Step 3: Add routes**

Add to `config/routes.rb` after the account settings routes block (after line 198):

```ruby
  # Password reset routes (public)
  get "password_reset/new", to: "password_resets#new", as: :password_reset_new
  get "password_reset/edit", to: "password_resets#edit", as: :password_reset_edit
  post "password_reset", to: "password_resets#create", as: :password_reset
  patch "password_reset", to: "password_resets#update"
```

- [ ] **Step 4: Create the controller**

Create `app/controllers/password_resets_controller.rb`:

```ruby
# frozen_string_literal: true

class PasswordResetsController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :verify_user_belongs_to_tenant!

  def new
    # Render email input form
  end

  def create
    user = User.find_by(email: params[:email]&.downcase)

    if user
      user.update!(password_reset_sent_at: Time.current)
      token = JwtService.generate_password_reset_token(user)
      UserMailer.password_reset(user, token).deliver_later
    end

    # Always show the same message to prevent email enumeration
    redirect_to password_reset_new_path, notice: "If an account exists with that email, we've sent reset instructions."
  end

  def edit
    @user = JwtService.verify_password_reset_token(params[:token])

    unless @user
      redirect_to password_reset_new_path, alert: "This reset link is invalid or has expired. Please request a new one."
      return
    end

    @token = params[:token]
  end

  def update
    @user = JwtService.verify_password_reset_token(params[:token])

    unless @user
      redirect_to password_reset_new_path, alert: "This reset link is invalid or has expired. Please request a new one."
      return
    end

    @token = params[:token]

    if params[:password].length < 6
      flash.now[:alert] = "Password must be at least 6 characters"
      render :edit, status: :unprocessable_entity
      return
    end

    if params[:password] != params[:password_confirmation]
      flash.now[:alert] = "Passwords don't match"
      render :edit, status: :unprocessable_entity
      return
    end

    ActsAsTenant.with_tenant(@user.community) do
      if @user.update(password: params[:password], password_confirmation: params[:password_confirmation])
        @user.update!(password_reset_sent_at: nil)
        redirect_to login_path, notice: "Password updated successfully. You can now log in."
      else
        flash.now[:alert] = @user.errors.full_messages.join(", ")
        render :edit, status: :unprocessable_entity
      end
    end
  end
end
```

- [ ] **Step 5: Create the new (request) view**

Create `app/views/password_resets/new.html.erb`:

```erb
<div class="container mx-auto px-4 py-16 flex justify-center">
  <div class="card bg-base-100 shadow-xl w-full max-w-md">
    <div class="card-body">
      <h2 class="card-title text-2xl font-bold text-center w-full justify-center mb-6">Reset Your Password</h2>

      <p class="text-base-content/70 text-center mb-6">
        Enter your email address and we'll send you instructions to reset your password.
      </p>

      <%= form_with url: password_reset_path, method: :post, class: "space-y-4" do |f| %>
        <div class="form-control">
          <%= f.label :email, class: "label" do %>
            <span class="label-text">Email</span>
          <% end %>
          <%= f.email_field :email, class: "input input-bordered w-full", required: true, autocomplete: "email", autofocus: true %>
        </div>

        <%= f.submit "Send Reset Link", class: "btn btn-primary w-full" %>
      <% end %>

      <div class="text-center mt-4">
        <%= link_to "Back to login", login_path, class: "link link-hover text-sm" %>
      </div>
    </div>
  </div>
</div>
```

- [ ] **Step 6: Create the edit (reset) view**

Create `app/views/password_resets/edit.html.erb`:

```erb
<div class="container mx-auto px-4 py-16 flex justify-center">
  <div class="card bg-base-100 shadow-xl w-full max-w-md">
    <div class="card-body">
      <h2 class="card-title text-2xl font-bold text-center w-full justify-center mb-6">Choose a New Password</h2>

      <%= form_with url: password_reset_path, method: :patch, class: "space-y-4" do |f| %>
        <%= hidden_field_tag :token, @token %>

        <div class="form-control">
          <%= f.label :password, "New Password", class: "label" %>
          <%= f.password_field :password, class: "input input-bordered w-full", required: true, minlength: 6, autocomplete: "new-password" %>
          <label class="label">
            <span class="label-text-alt text-base-content/50">Minimum 6 characters</span>
          </label>
        </div>

        <div class="form-control">
          <%= f.label :password_confirmation, "Confirm Password", class: "label" %>
          <%= f.password_field :password_confirmation, class: "input input-bordered w-full", required: true, autocomplete: "new-password" %>
        </div>

        <%= f.submit "Update Password", class: "btn btn-primary w-full" %>
      <% end %>
    </div>
  </div>
</div>
```

- [ ] **Step 7: Run tests to verify they pass**

Run:
```bash
bin/rails test test/controllers/password_resets_controller_test.rb
```
Expected: All pass.

- [ ] **Step 8: Commit**

```bash
git add app/controllers/password_resets_controller.rb app/views/password_resets/ test/controllers/password_resets_controller_test.rb config/routes.rb
git commit -m "Add password reset controller with request and reset flow"
```

---

### Task 5: Admin trigger — Send password reset from users list

**Files:**
- Modify: `app/controllers/users_controller.rb`
- Modify: `app/views/users/index.html.erb`
- Modify: `config/routes.rb`
- Create: `test/controllers/users_controller_password_reset_test.rb`

- [ ] **Step 1: Write failing tests**

Create `test/controllers/users_controller_password_reset_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class UsersControllerPasswordResetTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @user = users(:email_user)
    @community = communities(:crow_woods)
    host! @community.domain || "example.com"
    post login_path, params: { email: @admin.email, password: "password" }
  end

  test "admin can send password reset email for a user" do
    assert_emails 1 do
      post send_password_reset_user_path(@user)
    end
    assert_redirected_to users_path
    assert_match(/reset/, flash[:notice])
    @user.reload
    assert @user.password_reset_sent_at.present?
  end

  test "non-admin cannot send password reset" do
    delete logout_path
    regular = users(:regular_user)
    post login_path, params: { email: regular.email, password: "password" }

    post send_password_reset_user_path(@user)
    assert_redirected_to root_path
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
bin/rails test test/controllers/users_controller_password_reset_test.rb
```
Expected: FAIL — no route matches.

- [ ] **Step 3: Add route**

In `config/routes.rb`, change line 101:

```ruby
  resources :users, only: [ :index, :edit, :update, :destroy ] do
    member do
      post :send_password_reset
    end
  end
```

- [ ] **Step 4: Add controller action**

Add to `app/controllers/users_controller.rb`, after the `destroy` method (before `private`):

```ruby
  def send_password_reset
    @user = User.find(params[:id])
    @user.update!(password_reset_sent_at: Time.current)
    token = JwtService.generate_password_reset_token(@user)
    UserMailer.password_reset(@user, token).deliver_later

    redirect_to users_path, notice: "Password reset email sent to #{@user.email}."
  end
```

Also add `:send_password_reset` to the `set_user` before_action:

```ruby
  before_action :set_user, only: [ :edit, :update, :destroy, :send_password_reset ]
```

- [ ] **Step 5: Add button to users index view**

In `app/views/users/index.html.erb`, replace the Actions `<td>` (line 69-71):

```erb
                <td class="flex gap-1">
                  <%= link_to "Edit", edit_user_path(user), class: "btn btn-ghost btn-sm" %>
                  <%= button_to "Reset Password", send_password_reset_user_path(user), method: :post, class: "btn btn-ghost btn-sm", data: { turbo_confirm: "Send password reset email to #{user.email}?" } %>
                </td>
```

- [ ] **Step 6: Run tests to verify they pass**

Run:
```bash
bin/rails test test/controllers/users_controller_password_reset_test.rb
```
Expected: All pass.

- [ ] **Step 7: Commit**

```bash
git add app/controllers/users_controller.rb app/views/users/index.html.erb config/routes.rb test/controllers/users_controller_password_reset_test.rb
git commit -m "Add admin ability to send password reset emails from users list"
```

---

### Task 6: Web login page — Add "Forgot Password?" link

**Files:**
- Modify: `app/views/sessions/new.html.erb`

- [ ] **Step 1: Add the link**

In `app/views/sessions/new.html.erb`, add a "Forgot Password?" link after the password field and before the submit button. After line 32 (closing `</div>` of password form-control), add:

```erb
        <div class="text-right">
          <%= link_to "Forgot password?", password_reset_new_path, class: "link link-hover text-sm" %>
        </div>
```

- [ ] **Step 2: Verify it renders**

Run:
```bash
bin/rails test test/controllers/password_resets_controller_test.rb -n test_new_renders_the_request_form
```
Expected: PASS (confirms the route works end-to-end).

- [ ] **Step 3: Commit**

```bash
git add app/views/sessions/new.html.erb
git commit -m "Add forgot password link to web login page"
```

---

### Task 7: iOS — Add "Forgot Password?" button

**Files:**
- Modify: `ios/Conduit/Conduit/Controllers/LoginViewController.swift`

- [ ] **Step 1: Add the button property**

Add after the `passwordTextField` property declaration (line 13):

```swift
    private let forgotPasswordButton = UIButton(type: .system)
```

- [ ] **Step 2: Configure the button in setupUI()**

Add after the `passwordTextField` configuration block (after line 78), before the `// Login Button` comment:

```swift
        // Forgot Password Button
        forgotPasswordButton.setTitle("Forgot password?", for: .normal)
        forgotPasswordButton.titleLabel?.font = .systemFont(ofSize: 14)
        forgotPasswordButton.setTitleColor(.systemBlue, for: .normal)
        forgotPasswordButton.contentHorizontalAlignment = .trailing
        forgotPasswordButton.translatesAutoresizingMaskIntoConstraints = false
```

Add `view.addSubview(forgotPasswordButton)` in the `// Add subviews` section (after `view.addSubview(passwordTextField)`).

- [ ] **Step 3: Add constraints in setupConstraints()**

Replace the `loginButton.topAnchor` constraint (which currently anchors to `errorLabel`) to anchor to `forgotPasswordButton` instead. Add constraints for the forgot button between `passwordTextField` and `errorLabel`:

```swift
            // Forgot Password Button
            forgotPasswordButton.topAnchor.constraint(equalTo: passwordTextField.bottomAnchor, constant: 8),
            forgotPasswordButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            forgotPasswordButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),

            // Error Label (update to anchor below forgot password button)
            errorLabel.topAnchor.constraint(equalTo: forgotPasswordButton.bottomAnchor, constant: 8),
```

Remove the old `errorLabel.topAnchor` constraint that was anchored to `passwordTextField`.

- [ ] **Step 4: Add action in setupActions()**

Add after `loginButton.addTarget(...)`:

```swift
        forgotPasswordButton.addTarget(self, action: #selector(forgotPasswordTapped), for: .touchUpInside)
```

- [ ] **Step 5: Add the action method**

Add after `loginButtonTapped()`:

```swift
    @objc private func forgotPasswordTapped() {
        let baseURL = AppConfig.baseURL.absoluteString
        guard let url = URL(string: "\(baseURL)/password_reset/new") else { return }
        UIApplication.shared.open(url)
    }
```

- [ ] **Step 6: Commit**

```bash
git add ios/Conduit/Conduit/Controllers/LoginViewController.swift
git commit -m "Add forgot password button to iOS login screen"
```

---

### Task 8: Android — Add "Forgot Password?" button

**Files:**
- Modify: `android/app/src/main/res/layout/activity_login.xml`
- Modify: `android/app/src/main/java/com/colecoding/conduit/auth/LoginActivity.kt`

- [ ] **Step 1: Add the button to the layout**

In `activity_login.xml`, add after the `password_layout` `TextInputLayout` (after line 76, before the `btn_login` MaterialButton):

```xml
    <com.google.android.material.button.MaterialButton
        android:id="@+id/btn_forgot_password"
        style="@style/Widget.MaterialComponents.Button.TextButton"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_marginTop="4dp"
        android:text="Forgot password?"
        android:textAllCaps="false"
        android:textSize="14sp"
        app:layout_constraintEnd_toEndOf="parent"
        app:layout_constraintTop_toBottomOf="@id/password_layout" />
```

Update `btn_login` to anchor below the new button instead of `password_layout`:

```xml
        app:layout_constraintTop_toBottomOf="@id/btn_forgot_password"
```

- [ ] **Step 2: Add click listener in LoginActivity.kt**

In `setupClickListeners()`, add:

```kotlin
        binding.btnForgotPassword.setOnClickListener { openForgotPassword() }
```

- [ ] **Step 3: Add the method**

Add after `switchCommunity()`:

```kotlin
    private fun openForgotPassword() {
        val url = "${AppConfig.getBaseUrl(this)}/password_reset/new"
        startActivity(Intent(Intent.ACTION_VIEW, android.net.Uri.parse(url)))
    }
```

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/res/layout/activity_login.xml android/app/src/main/java/com/colecoding/conduit/auth/LoginActivity.kt
git commit -m "Add forgot password button to Android login screen"
```

---

### Task 9: Run full test suite and lint

**Files:** None (verification only)

- [ ] **Step 1: Run all tests**

Run:
```bash
bin/rails test
```
Expected: All pass.

- [ ] **Step 2: Run rubocop**

Run:
```bash
bin/rubocop
```
Expected: No offenses (fix any that appear).

- [ ] **Step 3: Run brakeman**

Run:
```bash
bin/brakeman --no-pager
```
Expected: No new warnings.

- [ ] **Step 4: Final commit if any fixes were needed**

Only if rubocop/brakeman required changes:
```bash
git add -A
git commit -m "Fix lint and security warnings"
```
