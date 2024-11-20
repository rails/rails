# frozen_string_literal: true

require "active_support/testing/strict_warnings"

ENV["RAILS_ENV"] = "test"
ENV["RAILS_INBOUND_EMAIL_PASSWORD"] = "tbsy84uSV1Kt3ZJZELY2TmShPRs91E3yL4tzf96297vBCkDWgL"

require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [ File.expand_path("../test/dummy/db/migrate", __dir__) ]
require "rails/test_help"

require "webmock/minitest"

require "rails/test_unit/reporter"
Rails::TestUnitReporter.executable = "bin/test"

if ActiveSupport::TestCase.respond_to?(:fixture_paths=)
  ActiveSupport::TestCase.fixture_paths = [File.expand_path("fixtures", __dir__)]
  ActionDispatch::IntegrationTest.fixture_paths = ActiveSupport::TestCase.fixture_paths
  ActiveSupport::TestCase.file_fixture_path = File.expand_path("fixtures", __dir__) + "/files"
  ActiveSupport::TestCase.fixtures :all
end

require "action_mailbox/test_helper"

class ActiveSupport::TestCase
  include ActionMailbox::TestHelper, ActiveJob::TestHelper
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
