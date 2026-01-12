class ApplicationMailer < ActionMailer::Base
  default from: -> {
    tenant = ActsAsTenant.current_tenant
    from_name = tenant&.smtp_from_name || "Conduit"
    from_email = ENV.fetch("DEFAULT_FROM_EMAIL", "noreply@conduitcoho.app")
    "#{from_name} <#{from_email}>"
  }
  layout "mailer"

  before_action :set_url_options
  after_action :set_community_header

  private

  def set_url_options
    tenant = ActsAsTenant.current_tenant
    if tenant&.domain.present?
      default_url_options[:host] = tenant.domain
      default_url_options[:protocol] = "https"
    end
  end

  def set_community_header
    tenant = ActsAsTenant.current_tenant
    mail.header["X-Community-ID"] = tenant.id.to_s if tenant
  end
end
