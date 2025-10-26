# SMTP settings example — use environment variables and secure secrets in production.
# This example is tailored for Gmail SMTP using an App Password.

if Rails.env.development? || Rails.env.production? || Rails.env.test?
  ActionMailer::Base.smtp_settings = {
    address: ENV.fetch('SMTP_ADDRESS', 'smtp.gmail.com'),
    port: ENV.fetch('SMTP_PORT', 587).to_i,
    domain: ENV.fetch('SMTP_DOMAIN', 'example.com'),
    user_name: ENV['SMTP_USERNAME'], # e.g. your Gmail address
    password: ENV['SMTP_PASSWORD'],  # use an App Password (recommended)
    authentication: ENV.fetch('SMTP_AUTHENTICATION', 'plain').to_sym,
    enable_starttls_auto: ENV.fetch('SMTP_ENABLE_STARTTLS_AUTO', 'true') == 'true'
  }

  # Default URL options are often required in mailers. Set HOST via env.
  ActionMailer::Base.default_url_options = { host: ENV.fetch('APP_HOST', 'localhost'), port: ENV.fetch('APP_PORT', 3000).to_i }
end
