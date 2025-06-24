# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  gem "rails"
  # If you want to test against edge Rails replace the previous line with this:
  # gem "rails", github: "rails/rails", branch: "main"

  gem "sqlite3"
  gem "net-smtp", github: "ruby/net-smtp", ref: "d496a829f9b99adb44ecc1768c4d005e5f7b779e", require: false
end

require "active_record/railtie"
require "active_storage/engine"
require "action_mailbox/engine"

ENV["DATABASE_URL"] = "sqlite3::memory:"

class TestApp < Rails::Application
  config.load_defaults Rails::VERSION::STRING.to_f

  config.root = __dir__
  config.hosts << "example.org"
  config.eager_load = false
  config.session_store :cookie_store, key: "cookie_store_key"
  config.secret_key_base = "secret_key_base"

  config.logger = Logger.new($stdout)

  config.active_storage.service = :local
  config.active_storage.service_configurations = {
    local: {
      root: Dir.tmpdir,
      service: "Disk"
    }
  }

  config.action_mailbox.ingress = :relay
end
Rails.application.initialize!

require ActiveStorage::Engine.root.join("db/migrate/20170806125915_create_active_storage_tables.rb").to_s
require ActionMailbox::Engine.root.join("db/migrate/20180917164000_create_action_mailbox_tables.rb").to_s

ActiveRecord::Schema.define do
  CreateActiveStorageTables.new.change
  CreateActionMailboxTables.new.change
end

class ApplicationMailbox < ActionMailbox::Base
  routing (/^replies@/i) => :replies
end

class RepliesMailbox < ActionMailbox::Base
  def process
    $processed = mail.subject
  end
end

require "minitest/autorun"

class RepliesMailboxTest < ActionMailbox::TestCase
  setup do
    $processed = false
    @inbound_email = receive_inbound_email_from_mail \
      to: "replies@example.com", subject: "Here is a reply"
  end

  test "successful mailbox processing" do
    assert_equal "Here is a reply", $processed
  end
end
