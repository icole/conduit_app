class ApplicationMailer < ActionMailer::Base
  default from: -> {
    tenant = ActsAsTenant.current_tenant
    from_name = tenant&.smtp_from_name || "Conduit"
    "#{from_name} <#{ENV.fetch('SMTP_USERNAME', 'info@conduit.app')}>"
  }
  layout "mailer"
end
