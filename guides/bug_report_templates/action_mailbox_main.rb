# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  git_source(:github) { |repo| "https://github.com/#{repo}.git" }

  gem "rails", github: "rails/rails", branch: "main"
  gem "sqlite3"
  if RUBY_VERSION >= "3.1"
    # net-smtp, net-imap and net-pop were removed from default gems in Ruby 3.1, but is used by the `mail` gem.
    # So we need to add them as dependencies until `mail` is fixed: https://github.com/mikel/mail/pull/1439
    gem "net-smtp", require: false
  end
end

require "active_record/railtie"
require "active_storage/engine"
require "action_mailbox/engine"
require "tmpdir"

class TestApp < Rails::Application
  config.root = __dir__
  config.hosts << "example.org"
  config.eager_load = false
  config.session_store :cookie_store, key: "cookie_store_key"
  secrets.secret_key_base = "secret_key_base"

  config.logger = Logger.new($stdout)
  Rails.logger  = config.logger

  config.active_storage.service = :local
  config.active_storage.service_configurations = {
    local: {
      root: Dir.tmpdir,
      service: "Disk"
    }
  }

  config.action_mailbox.ingress = :relay
end

ENV["DATABASE_URL"] = "sqlite3::memory:"

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
