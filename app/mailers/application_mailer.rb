class ApplicationMailer < ActionMailer::Base
  # Prefer an explicit MAIL_FROM env var, otherwise use the SMTP username if available
  # or fall back to a no-reply address at the configured SMTP domain.
  default from: ENV.fetch('MAIL_FROM') { ENV['SMTP_USERNAME'] || "no-reply@#{ENV.fetch('SMTP_DOMAIN', 'gmail.com')}" }
  layout "mailer"
end
