# frozen_string_literal: true

require "active_support/testing/strict_warnings"

ENV["RAILS_ENV"] = "test"
ENV["RAILS_INBOUND_EMAIL_PASSWORD"] = "tbsy84uSV1Kt3ZJZELY2TmShPRs91E3yL4tzf96297vBCkDWgL"

#ActiveRecord::Migrator.migrations_paths = [File.expand_path("../test/dummy/db/migrate", __dir__)]
#require "rails/test_help"

require "webmock/minitest"

require "rails/test_unit/reporter"
Rails::TestUnitReporter.executable = "bin/test"

#if ActiveSupport::TestCase.respond_to?(:fixture_paths=)
#  ActiveSupport::TestCase.fixture_paths = [File.expand_path("fixtures", __dir__)]
#  ActionDispatch::IntegrationTest.fixture_paths = ActiveSupport::TestCase.fixture_paths
#  ActiveSupport::TestCase.file_fixture_path = File.expand_path("fixtures", __dir__) + "/files"
#  ActiveSupport::TestCase.fixtures :all
#end

require "rails"
require "rails/generators"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "active_storage/engine"
require "active_job/railtie"

module ActionMailbox
  class TestApp < Rails::Application
    config.eager_load = false # ENV["CI"].present?

    # config.logger = Logger.new($stdout)
    # Rails.logger  = config.logger

    config.root = File.join(__dir__, "support")

    #config.fixture_paths = [File.expand_path("fixtures", __dir__)]

    #config.autoload_paths << File.join(__dir__, "support", "jobs")
    #config.autoload_paths << File.join(__dir__, "support", "models")
    #config.autoload_paths << File.join(__dir__, "support", "mailers")
    #config.autoload_paths << File.join(__dir__, "support", "controllers")
    #config.paths["app/views"] << File.join(__dir__, "support", "views")

    config.active_storage.service = :test

    #config.load_defaults 7.1

    # Raise exceptions instead of rendering exception templates.
    config.action_dispatch.show_exceptions = :rescuable

    # Tell Action Mailer not to deliver emails to the real world.
    # The :test delivery method accumulates sent emails in the
    # ActionMailer::Base.deliveries array.
    config.action_mailer.delivery_method = :test

    # Raise error when a before_action's only/except options reference missing actions
    config.action_controller.raise_on_missing_callback_actions = true

    # FIXME: need to disable CSRF protection for this test in particular:
    # test/controllers/rails/action_mailbox/inbound_emails_controller_test.rb
    config.action_controller.allow_forgery_protection = false

    # FIXME: test/template/form_helper_test.rb assumes the following defaults
    # (original): true
    # 6.0: false
    # https://edgeguides.rubyonrails.org/configuring.html#config-action-view-default-enforce-utf8
    #config.action_view.default_enforce_utf8 = false
    # (original): false
    # 5.2: true
    # https://edgeguides.rubyonrails.org/configuring.html#config-action-view-form-with-generates-ids
    #config.action_view.form_with_generates_ids = true

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
end

ActiveRecord::Base.connection.migration_context.migrate

require "action_mailbox/test_helper"

class ActiveSupport::TestCase
  include ActionMailbox::TestHelper, ActiveJob::TestHelper

  ActiveStorage::FixtureSet.file_fixture_path = File.expand_path("fixtures/files", __dir__)
  self.file_fixture_path = ActiveStorage::FixtureSet.file_fixture_path

  include ActiveRecord::TestFixtures

  self.fixture_paths = [File.expand_path("fixtures", __dir__)]
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

if ARGV.include?("-v")
  ActiveRecord::Base.logger = Logger.new(STDOUT)
  ActiveJob::Base.logger    = Logger.new(STDOUT)
end

class BounceMailer < ActionMailer::Base
  def bounce(to:)
    mail from: "receiver@example.com", to: to, subject: "Your email was not delivered" do |format|
      format.html { render plain: "Sorry!" }
    end
  end
end

require_relative "../../tools/test_common"
