# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

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
    policy.form_action :self

    # Send violation reports to Sentry
    if ENV["SENTRY_CSP_REPORT_URI"].present?
      policy.report_uri ENV["SENTRY_CSP_REPORT_URI"]
    end
  end

  # Generate session nonces for permitted importmap and inline scripts.
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]

  # Enforced everywhere except production, so a blocked script fails loudly for
  # developers and fails the system tests (see test/application_system_test_case.rb)
  # instead of silently doing nothing. Production stays report-only until the
  # policy has been verified against the real Stream and Liveblocks traffic that
  # no test reaches — CON-53 step 3. Note that report-only sends nothing at all
  # today: no report_uri is configured in production.
  config.content_security_policy_report_only = Rails.env.production?
end
