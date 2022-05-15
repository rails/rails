# frozen_string_literal: true

require "test_helper"

class Rails::Conductor::ActionMailbox::InboundEmailsControllerTest < ActionDispatch::IntegrationTest
  test "create inbound email" do
    with_rails_env("development") do
      assert_difference -> { ActionMailbox::InboundEmail.count }, +1 do
        post rails_conductor_inbound_emails_path, params: {
          mail: {
            from: "Jason Fried <jason@37signals.com>",
            to: "Replies <replies@example.com>",
            cc: "CC <cc@example.com>",
            bcc: "Bcc <bcc@example.com>",
            in_reply_to: "<4e6e35f5a38b4_479f13bb90078178@small-app-01.mail>",
            subject: "Hey there",
            body: "How's it going?"
          }
        }
      end

      mail = ActionMailbox::InboundEmail.last.mail
      assert_equal %w[ jason@37signals.com ], mail.from
      assert_equal %w[ replies@example.com ], mail.to
      assert_equal %w[ cc@example.com ], mail.cc
      assert_equal %w[ bcc@example.com ], mail.bcc
      assert_equal "4e6e35f5a38b4_479f13bb90078178@small-app-01.mail", mail.in_reply_to
      assert_equal "Hey there", mail.subject
      assert_equal "How's it going?", mail.body.decoded
    end
  end

  test "create inbound email with bcc" do
    with_rails_env("development") do
      assert_difference -> { ActionMailbox::InboundEmail.count }, +1 do
        post rails_conductor_inbound_emails_path, params: {
          mail: {
            from: "Jason Fried <jason@37signals.com>",
            bcc: "Replies <replies@example.com>",
            subject: "Hey there",
            body: "How's it going?"
          }
        }
      end

      mail = ActionMailbox::InboundEmail.last.mail
      assert_equal %w[ jason@37signals.com ], mail.from
      assert_equal %w[ replies@example.com ], mail.bcc
      assert_equal "Hey there", mail.subject
      assert_equal "How's it going?", mail.body.decoded
    end
  end

  test "create inbound email with attachments" do
    with_rails_env("development") do
      assert_difference -> { ActionMailbox::InboundEmail.count }, +1 do
        post rails_conductor_inbound_emails_path, params: {
          mail: {
            from: "Jason Fried <jason@37signals.com>",
            to: "Replies <replies@example.com>",
            subject: "Let's debate some attachments",
            body: "Let's talk about these images:",
            attachments: [ fixture_file_upload("avatar1.jpeg"), fixture_file_upload("avatar2.jpeg") ]
          }
        }
      end

      mail = ActionMailbox::InboundEmail.last.mail
      assert_equal "Let's talk about these images:", mail.text_part.decoded
      assert_equal 2, mail.attachments.count
      assert_equal %w[ avatar1.jpeg avatar2.jpeg ], mail.attachments.collect(&:filename)
    end
  end

  test "create inbound email with empty attachment" do
    with_rails_env("development") do
      assert_difference -> { ActionMailbox::InboundEmail.count }, +1 do
        post rails_conductor_inbound_emails_path, params: {
          mail: {
            from: "",
            to: "",
            cc: "",
            bcc: "",
            x_original_to: "",
            subject: "",
            in_reply_to: "",
            body: "",
            attachments: [ "" ],
          }
        }
      end

      mail = ActionMailbox::InboundEmail.last.mail
      assert_equal 0, mail.attachments.count
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
