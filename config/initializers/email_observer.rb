# frozen_string_literal: true

Rails.application.config.after_initialize do
  # Interceptor runs BEFORE delivery - creates pending log entry
  ActionMailer::Base.register_interceptor(EmailLogInterceptor)

  # Observer runs AFTER successful delivery - updates to delivered
  ActionMailer::Base.register_observer(EmailLogObserver)
end
