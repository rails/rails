# frozen_string_literal: true

require_relative "../../tools/strict_warnings"

require "openssl"

require "action_text"

require "action_controller"
require "action_mailer"
require "action_view"
require "active_job"
require "active_record"
require "active_record/testing/query_assertions"

require "active_storage"
require "active_storage/reflection"
require "active_storage/service/registry"

require "zeitwerk"
loader = Zeitwerk::Loader.new
loader.push_dir("app/helpers")
loader.push_dir("app/models")
loader.push_dir("app/views")

loader.push_dir("test/support/controllers")
loader.push_dir("test/support/models")

RAILS_ROOT = Pathname.new(__dir__).join("../..")

loader.push_dir(RAILS_ROOT.join("activestorage/app/models"))

loader.setup

ActiveStorage.verifier = ActiveSupport::MessageVerifier.new("Testing")
ActiveStorage.variable_content_types = %w( image/jpeg )

module Rails
  class << self
    def application
      @app ||= Application.new
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def env
      "test"
    end

    def logger
      @logger ||= Logger.new($stdout).tap { |logger| logger.level = Logger::ERROR }
    end

    attr_writer :logger
  end

  class Application
    def config
      Rails.configuration
    end

    def env_config
      {}
    end

    def routes
      @routes ||= ActionDispatch::Routing::RouteSet.new
    end
  end

  class Configuration
    def active_storage
      @active_storage ||= ActiveSupport::OrderedOptions.new.tap do |config|
        config.service = :local
      end
    end

    def generators(&block)
      @generators ||= GeneratorConfig.new
      yield @generators if block_given?
      @generators
    end
  end

  class GeneratorConfig
    attr_accessor :options

    def initialize
      @options = { active_record: { primary_key_type: nil } }
      @orm = :active_record
    end

    def orm(orm = nil, options = {})
      if orm
        @options[orm] = options
      else
        @orm
      end
    end
  end
end

Rails.application.routes.draw do
  load RAILS_ROOT.join("activestorage/config/routes.rb")

  resources :messages
end

Rails.application.routes.default_url_options = { host: "www.example.com" }

class RoutedRackApp
  attr_reader :routes

  def initialize(routes, &blk)
    @routes = routes
    @stack = ActionDispatch::MiddlewareStack.new(&blk)
    @app = @stack.build(@routes)
  end

  def call(env)
    @app.call(env)
  end
end

class ActionDispatch::IntegrationTest < ActiveSupport::TestCase
  def self.build_app
    RoutedRackApp.new(Rails.application.routes) do |middleware|
      yield(middleware) if block_given?
    end
  end

  self.app = build_app
end

Rails.application.routes.define_mounted_helper(:main_app)

ActionController::Base.include(Rails.application.routes.url_helpers)
ActionController::Base.include(Rails.application.routes.mounted_helpers)

ActionController::Base.prepend_view_path("app/views")
ActionController::Base.append_view_path("test/support/views")

ActiveSupport.on_load(:active_storage_blob) do
  include ActionText::Attachable

  def previewable_attachable?
    representable?
  end

  def attachable_plain_text_representation(caption = nil)
    "[#{caption || filename}]"
  end

  def to_trix_content_attachment_partial_path
    nil
  end
end

ActiveRecord.include(ActiveStorage::Attached::Model)
ActiveRecord::Base.include(ActiveStorage::Attached::Model)

ActiveRecord::Base.include(ActiveStorage::Reflection::ActiveRecordExtensions)
ActiveRecord::Reflection.singleton_class.prepend(ActiveStorage::Reflection::ReflectionExtension)

ActiveSupport.on_load(:active_record) do
  include ActionText::Attribute
  prepend ActionText::Encryption
end

ActiveSupport.on_load(:active_record) do
  ActiveStorage.singleton_class.redefine_method(:table_name_prefix) do
    "#{ActiveRecord::Base.table_name_prefix}active_storage_"
  end
  ActionText.singleton_class.redefine_method(:table_name_prefix) do
    "#{ActiveRecord::Base.table_name_prefix}action_text_"
  end
end

ActiveRecord::Migrator.migrations_paths << File.expand_path("support/migrations", __dir__)
ActiveRecord::Migrator.migrations_paths << File.expand_path("../../activestorage/db/migrate", __dir__)
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

ActiveRecord::Base.connection_pool.migration_context.migrate

ActiveStorage::Blob.services = ActiveStorage::Service::Registry.new({
  "test" => { "service" => "Disk", "root" => Dir.mktmpdir("action_text_tests") },
  "local" => { "service" => "Disk", "root" => Dir.mktmpdir("action_text_tests_local") },
})
ActiveStorage::Blob.service = ActiveStorage::Blob.services.fetch(:test)

ActiveJob::Base.queue_adapter = :test

ActionView::Helpers::FormHelper.form_with_generates_remote_forms = false
ActionView::Helpers::FormHelper.form_with_generates_ids = true
ActionView::Helpers::FormTagHelper.default_enforce_utf8 = false

ActionController::Base.helper ActionText::ContentHelper, ActionText::TagHelper

require "rails/test_unit/reporter"
Rails::TestUnitReporter.executable = "bin/test"

# Disable available locale checks to allow to add locale after initialized.
I18n.enforce_available_locales = false

class ActiveSupport::TestCase
  module QueryHelpers
    include ActiveRecord::Assertions::QueryAssertions
  end

  include ActiveRecord::TestFixtures

  self.fixture_paths = [File.expand_path("fixtures", __dir__)]
  self.file_fixture_path = File.expand_path("fixtures/files", __dir__)
  fixtures :all

  private
    def create_file_blob(filename:, content_type:, metadata: nil)
      ActiveStorage::Blob.create_and_upload! io: file_fixture(filename).open, filename: filename, content_type: content_type, metadata: metadata
    end
end

require "global_id"

require "global_id/fixture_set"
ActiveRecord::FixtureSet.extend(GlobalID::FixtureSet)

GlobalID.app = "actiontext_test"
ActiveRecord::Base.include(GlobalID::Identification)

key_generator = ActiveSupport::KeyGenerator.new("actiontext_tests_generator")
verifier = GlobalID::Verifier.new(key_generator.generate_key("signed_global_ids"))
SignedGlobalID.verifier = verifier

# Encryption
ActiveRecord::Encryption.configure \
  primary_key: "test master key",
  deterministic_key: "test deterministic key",
  key_derivation_salt: "testing key derivation salt",
  support_unencrypted_data: true

Time.zone = "UTC"

require_relative "../../tools/test_common"
