class ApplicationMailer < ActionMailer::Base
  default from: -> {
    tenant = ActsAsTenant.current_tenant
    from_name = tenant&.smtp_from_name || "Conduit"
    "#{from_name} <#{ENV.fetch('SMTP_USERNAME', 'info@conduit.app')}>"
  }
  layout "mailer"

  # Add community ID header for email logging
  after_action :set_community_header

  private

  def set_community_header
    tenant = ActsAsTenant.current_tenant
    mail.header["X-Community-ID"] = tenant.id.to_s if tenant
  end
end
