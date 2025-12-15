class ApplicationMailer < ActionMailer::Base
  default from: -> { "Crow Woods Conduit <#{ENV.fetch('SMTP_USERNAME', 'info@crowwoods.com')}>" }
  layout "mailer"
end
