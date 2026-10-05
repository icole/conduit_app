# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

# Sentry takes CSP reports at its "security" endpoint, which is derived from the
# DSN; nil without a usable DSN (development, test)
module SentryCspReportUri
  def self.from_dsn(dsn)
    uri = URI.parse(dsn.to_s)
    project = uri.path.to_s.delete_prefix("/")
    return if uri.host.blank? || uri.user.blank? || project.blank?

    "#{uri.scheme}://#{uri.host}/api/#{project}/security/?sentry_key=#{uri.user}"
  rescue URI::InvalidURIError
    nil
  end
end

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data, "fonts.gstatic.com"
    policy.img_src     :self, :https, :data, :blob
    policy.object_src  :none
    policy.script_src  :self, :https
    policy.style_src   :self, :https, :unsafe_inline, "fonts.googleapis.com"
    policy.connect_src :self, :https, :wss
    policy.frame_src   :none
    policy.base_uri    :self
    # Google sign-in posts here and is redirected to Google, which form-action covers
    policy.form_action :self, "https://accounts.google.com"

    if (report_uri = SentryCspReportUri.from_dsn(ENV["SENTRY_DSN"]))
      policy.report_uri report_uri
    end
  end

  # Generate session nonces for permitted importmap and inline scripts.
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]

  # Enforced everywhere, and violations still go to Sentry. A blocked script
  # fails the system tests (see test/application_system_test_case.rb); the
  # pages no test reaches (Stream chat, the Liveblocks editor, Google sign-in,
  # the apps' chat prompt) were checked in a browser against production first
  # (CON-53).
  config.content_security_policy_report_only = false
end
