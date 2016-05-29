# Be sure to restart your server when you modify this file.

# Configure SSL options to enable HSTS with subdomains. This is a new
# Rails 5.0 default, so it is introduced as a configuration option to ensure
# that apps made on earlier versions of Rails are not affected when upgrading.
Rails.application.config.ssl_options = { hsts: { subdomains: true } }
