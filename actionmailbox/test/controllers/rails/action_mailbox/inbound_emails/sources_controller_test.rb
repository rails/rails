# frozen_string_literal: true

require "test_helper"

class Rails::Conductor::ActionMailbox::InboundEmails::SourcesControllerTest < ActionDispatch::IntegrationTest
  test "create inbound email from source" do
    with_rails_env("development") do
      assert_difference -> { ActionMailbox::InboundEmail.count }, +1 do
        post rails_conductor_inbound_email_sources_path, params: {
          source: file_fixture("welcome.eml").read
        }
      end

      mail = ActionMailbox::InboundEmail.last
      assert_response :redirect
      assert_equal file_fixture("welcome.eml").read, mail.raw_email.download
      assert_equal "0CB459E0-0336-41DA-BC88-E6E28C697DDB@37signals.com", mail.message_id
    end
  end

  test "uploading same email multiple times fail" do
    with_rails_env("development") do
      assert_difference -> { ActionMailbox::InboundEmail.count }, +1 do
        post rails_conductor_inbound_email_sources_path, params: {
          source: file_fixture("welcome.eml").read
        }
        post rails_conductor_inbound_email_sources_path, params: {
          source: file_fixture("welcome.eml").read
        }
      end

      mail = ActionMailbox::InboundEmail.last
      assert_response :unprocessable_entity
      assert_equal file_fixture("welcome.eml").read, mail.raw_email.download
      assert_equal "0CB459E0-0336-41DA-BC88-E6E28C697DDB@37signals.com", mail.message_id
      assert_equal "This exact email has already been delivered", flash[:alert]
    end
  end

  private
    def with_rails_env(env)
      old_rails_env = Rails.env
      Rails.env = env
      yield
    ensure
      Rails.env = old_rails_env
    end
end
