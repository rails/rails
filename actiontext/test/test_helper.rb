# frozen_string_literal: true

require "active_support/testing/strict_warnings"

# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require "rails"
require "action_mailer/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_text/engine"
require "active_record/testing/query_assertions"
#require "rails/test_help"

require "rails/test_unit/reporter"
Rails::TestUnitReporter.executable = "bin/test"

# Disable available locale checks to allow to add locale after initialized.
I18n.enforce_available_locales = false

module ActiveText
  class TestApp < Rails::Application
    config.eager_load = false # ENV["CI"].present?

    # config.logger = Logger.new($stdout)
    # Rails.logger  = config.logger

    config.root = File.join(__dir__, "support")

    #config.fixture_paths = [File.expand_path("fixtures", __dir__)]

    config.autoload_paths << File.join(__dir__, "support", "jobs")
    config.autoload_paths << File.join(__dir__, "support", "models")
    config.autoload_paths << File.join(__dir__, "support", "mailers")
    config.autoload_paths << File.join(__dir__, "support", "controllers")
    config.paths["app/views"] << File.join(__dir__, "support", "views")

    config.active_storage.service = :test

    # FIXME: test/template/form_helper_test.rb assumes the following defaults
    # (original): true
    # 6.0: false
    # https://edgeguides.rubyonrails.org/configuring.html#config-action-view-default-enforce-utf8
    config.action_view.default_enforce_utf8 = false
    # (original): false
    # 5.2: true
    # https://edgeguides.rubyonrails.org/configuring.html#config-action-view-form-with-generates-ids
    config.action_view.form_with_generates_ids = true

    #config.active_record.table_name_prefix = 'prefix_'
    #config.active_record.table_name_suffix = '_suffix'

    #config.action_mailer.default_url_options = { protocol: "https://", host: "example.com", port: nil }

    #routes.draw do
    #  resources :messages
#
    #  namespace :admin do
    #    resources :messages, only: [:show]
    #  end
    #end
  end
end

Rails.application.initialize!

require ActiveStorage::Engine.root.join("db/migrate/20170806125915_create_active_storage_tables.rb").to_s

ActiveRecord::Schema.define do
  CreateActiveStorageTables.new.change

  create_table :messages do |t|
    t.string :subject
    t.timestamps
  end

  create_table :people do |t|
    t.string :name

    t.timestamps
  end

  create_table :pages do |t|
    t.string :title

    t.timestamps
  end

  create_table :reviews do |t|
    t.belongs_to :message, null: false
    t.string :author_name, null: false
  end
end

# FIXME: actiontext was originally doing this, with all required migrations in the dummy app
# However, if this is set then AR doesn't know about the db/migrate folder at the root
# TIL that this is how the ActiveStorage migrations are loaded since I wasn't manually requiring them.
# Not sure what to do here yet.
#ActiveRecord::Migrator.migrations_paths = [File.expand_path("support/db/migrate", __dir__)]

# NOTE: We use an in-memory SQLite database for testing
#ActiveRecord::Base.connects_to(database: { writing: :primary, reading: :replica })
ActiveRecord::Base.connection.migration_context.migrate

# Load fixtures from the engine
#ActiveSupport::TestCase.file_fixture_path = File.expand_path("fixtures", __dir__) + "/files"

#if ActiveSupport::TestCase.respond_to?(:fixture_paths=)
  #binding.irb
  #ActiveSupport::TestCase.fixture_paths = [File.expand_path("fixtures", __dir__)]
  #ActionDispatch::IntegrationTest.fixture_paths = ActiveSupport::TestCase.fixture_paths
  #ActiveSupport::TestCase.file_fixture_path = File.expand_path("fixtures", __dir__) + "/files"
  #ActiveStorage::FixtureSet.file_fixture_path = ActiveSupport::TestCase.file_fixture_path #File.expand_path("fixtures/files", __dir__)

  #ActiveStorage::FixtureSet.file_fixture_path = File.expand_path("fixtures/files", __dir__)
  #ActiveSupport::TestCase.file_fixture_path = ActiveStorage::FixtureSet.file_fixture_path

  #ActiveSupport::TestCase.fixtures :all
#end

class ActiveSupport::TestCase
  ActiveStorage::FixtureSet.file_fixture_path = File.expand_path("fixtures/files", __dir__)
  self.file_fixture_path = ActiveStorage::FixtureSet.file_fixture_path

  include ActiveRecord::TestFixtures

  self.fixture_paths = [File.expand_path("fixtures", __dir__)]

  module QueryHelpers
    include ActiveJob::TestHelper
    include ActiveRecord::Assertions::QueryAssertions
  end

  setup do
    #ActionMailer::Current.url_options = { protocol: "https://", host: "example.com", port: nil }
  end

  teardown do
    #ActionText::Current.reset
  end

  private
    def create_file_blob(filename:, content_type:, metadata: nil)
      ActiveStorage::Blob.create_and_upload! io: file_fixture(filename).open, filename: filename, content_type: content_type, metadata: metadata
    end
end

# Encryption
ActiveRecord::Encryption.configure \
  primary_key: "test master key",
  deterministic_key: "test deterministic key",
  key_derivation_salt: "testing key derivation salt",
  support_unencrypted_data: true

require_relative "../../tools/test_common"
