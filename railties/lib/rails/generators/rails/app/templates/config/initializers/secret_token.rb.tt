# Be sure to restart your server if you modify the value of secret_key_base.

# Your secret key is used for verifying the integrity of signed cookies.
# If you change this key, all old signed cookies will become invalid!

# Make sure the secret is at least 30 characters and all random, no regular
# words or you'll be exposed to dictionary attacks.

# You may use `rake secret` to generate a secure secret key, then set that
# value in the 'SECRET_TOKEN' environment variable, or set the value of
# Rails.application.config.secret_key_base below below to the secret string.

# Make sure your secret_key_base is kept private!

raise "You must set a secret token in the 'SECRET_TOKEN' environment "\
  "variable or "\
  "in config/initializers/secret_token.rb" if ENV['SECRET_TOKEN'].blank?

Rails.application.config.secret_key_base = ENV['SECRET_TOKEN']
