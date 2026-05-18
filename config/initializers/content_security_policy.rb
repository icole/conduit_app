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

  # Report violations without enforcing the policy initially.
  # Remove this line once you've verified no legitimate resources are blocked.
  config.content_security_policy_report_only = true
end
