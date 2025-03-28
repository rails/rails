# frozen_string_literal: true

require_relative "../../tools/strict_warnings"

ENV["RAILS_INBOUND_EMAIL_PASSWORD"] = "tbsy84uSV1Kt3ZJZELY2TmShPRs91E3yL4tzf96297vBCkDWgL"

require "action_mailbox"

require "action_mailer"
require "action_controller"
require "active_job"
require "active_record"
require "rails/generators"

require "active_storage"
require "active_storage/reflection"
require "active_storage/service/registry"

require "zeitwerk"
loader = Zeitwerk::Loader.new
loader.push_dir("app/controllers")
loader.push_dir("app/jobs")
loader.push_dir("app/models")

RAILS_ROOT = Pathname.new(__dir__).join("../..")

loader.push_dir(RAILS_ROOT.join("activestorage/app/controllers"))
loader.push_dir(RAILS_ROOT.join("activestorage/app/controllers/concerns"))
loader.push_dir(RAILS_ROOT.join("activestorage/app/jobs"))
loader.push_dir(RAILS_ROOT.join("activestorage/app/models"))

loader.setup

module Rails
  class << self
    def application
      @app ||= Application.new
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def env
      @env ||= Env.new
    end

    def env=(env)
      @env.instance_variable_set(:@env, env)
    end
  end

  class Application
    def config
      Rails.configuration
    end

    def credentials
      {}
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

  class Env
    def initialize
      @env = "test"
    end

    [:development?, :test?, :production?].each do |method|
      define_method(method) { @env == method.to_s.delete("?") }
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

load "config/routes.rb"
Rails.application.routes.default_url_options = { host: "www.example.com" }
Rails.application.routes.define_mounted_helper(:main_app)

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

ActionController::Base.include(Rails.application.routes.url_helpers)
ActionController::Base.include(Rails.application.routes.mounted_helpers)

ActiveRecord.include(ActiveStorage::Attached::Model)
ActiveRecord::Base.include(ActiveStorage::Attached::Model)

ActiveRecord::Base.include(ActiveStorage::Reflection::ActiveRecordExtensions)
ActiveRecord::Reflection.singleton_class.prepend(ActiveStorage::Reflection::ReflectionExtension)

ActiveSupport.on_load(:active_record) do
  ActiveStorage.singleton_class.redefine_method(:table_name_prefix) do
    "#{ActiveRecord::Base.table_name_prefix}active_storage_"
  end
  ActionMailbox.singleton_class.redefine_method(:table_name_prefix) do
    "#{ActiveRecord::Base.table_name_prefix}action_mailbox_"
  end
end

ActiveRecord::Migrator.migrations_paths << File.expand_path("../../activestorage/db/migrate", __dir__)
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

ActiveRecord::Base.connection_pool.migration_context.migrate

ActiveStorage::Blob.services = ActiveStorage::Service::Registry.new({
  "test" => { "service" => "Disk", "root" => Dir.mktmpdir("active_mailbox_tests") },
  "local" => { "service" => "Disk", "root" => Dir.mktmpdir("active_mailbox_tests_local") },
  "test_email" => { "service" => "Disk", "root" => Dir.mktmpdir("active_mailbox_storage_email") },
})
ActiveStorage::Blob.service = ActiveStorage::Blob.services.fetch(:local)

require "webmock/minitest"

require "rails/test_unit/reporter"
Rails::TestUnitReporter.executable = "bin/test"

require "action_mailbox/test_helper"

class ActiveSupport::TestCase
  include ActionMailbox::TestHelper, ActiveJob::TestHelper
  include ActiveRecord::TestFixtures

  self.fixture_paths = [File.expand_path("fixtures", __dir__)]
  self.file_fixture_path = File.expand_path("fixtures/files", __dir__)
  fixtures :all
end

class ActionDispatch::IntegrationTest
  private
    def credentials
      ActionController::HttpAuthentication::Basic.encode_credentials "actionmailbox", ENV["RAILS_INBOUND_EMAIL_PASSWORD"]
    end

    def switch_password_to(new_password)
      previous_password, ENV["RAILS_INBOUND_EMAIL_PASSWORD"] = ENV["RAILS_INBOUND_EMAIL_PASSWORD"], new_password
      yield
    ensure
      ENV["RAILS_INBOUND_EMAIL_PASSWORD"] = previous_password
    end
end

ActiveJob::Base.queue_adapter = :test
ActiveJob::Base.logger = Logger.new(STDOUT).tap { |logger| logger.level = Logger::ERROR }
ActionMailer::Base.delivery_method = :test

if ARGV.include?("-v")
  ActiveRecord::Base.logger = Logger.new(STDOUT)
  ActiveJob::Base.logger    = Logger.new(STDOUT)
end

ActionMailbox.logger = ActiveSupport::Logger.new(STDOUT)

require "global_id"
GlobalID.app = "actionmailbox_test"
ActiveRecord::Base.include(GlobalID::Identification)

Time.zone = "UTC"

class BounceMailer < ActionMailer::Base
  def bounce(to:)
    mail from: "receiver@example.com", to: to, subject: "Your email was not delivered" do |format|
      format.html { render plain: "Sorry!" }
    end
  end
end

require_relative "../../tools/test_common"
