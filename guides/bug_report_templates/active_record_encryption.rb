# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  gem "rails"
  # If you want to test against edge Rails replace the previous line with this:
  # gem "rails", github: "rails/rails", branch: "main"

  gem "sqlite3"
end

require "active_record/railtie"
require "minitest/autorun"

# This connection will do for database-independent bug reports.
ENV["DATABASE_URL"] = "sqlite3::memory:"

class TestApp < Rails::Application
  config.load_defaults Rails::VERSION::STRING.to_f
  config.eager_load = false
  config.logger = Logger.new($stdout)
  config.secret_key_base = "secret_key_base"

  config.active_record.encryption.primary_key = "primary_key"
  config.active_record.encryption.deterministic_key = "deterministic_key"
  config.active_record.encryption.key_derivation_salt = "key_derivation_salt"
end
Rails.application.initialize!

ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :email
  end
end

class User < ActiveRecord::Base
  encrypts :email
end

class BugTest < ActiveSupport::TestCase
  def test_encryption_stuff
    post = User.create!(email: "test@example.com")

    encrypted_email = post.read_attribute_before_type_cast(:email)

    assert_not_equal "test@example.com", encrypted_email
    assert_not_equal post.read_attribute(:email), encrypted_email

    assert_equal "test@example.com", post.email
  end
end
