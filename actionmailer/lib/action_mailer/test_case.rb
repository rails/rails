# frozen_string_literal: true

require "active_support/test_case"
require "rails-dom-testing"

module ActionMailer
  class NonInferrableMailerError < ::StandardError
    def initialize(name)
      super "Unable to determine the mailer to test from #{name}. " \
        "You'll need to specify it using tests YourMailer in your " \
        "test case definition"
    end
  end

  class TestCase < ActiveSupport::TestCase
    module ClearTestDeliveries
      extend ActiveSupport::Concern

      included do
        setup :clear_test_deliveries
        teardown :clear_test_deliveries
      end

      private
        def clear_test_deliveries
          if ActionMailer::Base.delivery_method == :test
            ActionMailer::Base.deliveries.clear
          end
        end
    end

    module Behavior
      extend ActiveSupport::Concern

      include ActiveSupport::Testing::ConstantLookup
      include TestHelper
      include Rails::Dom::Testing::Assertions::SelectorAssertions
      include Rails::Dom::Testing::Assertions::DomAssertions

      included do
        class_attribute :_decoders, default: Hash.new(->(body) { body }).merge!(
          Mime[:html] => ->(body) { Rails::Dom::Testing.html_document.parse(body) }
        ).freeze # :nodoc:
        class_attribute :_mailer_class
        setup :initialize_test_deliveries
        setup :set_expected_mail
        teardown :restore_test_deliveries
        ActiveSupport.run_load_hooks(:action_mailer_test_case, self)
      end

      module ClassMethods
        def tests(mailer)
          case mailer
          when String, Symbol
            self._mailer_class = mailer.to_s.camelize.constantize
          when Module
            self._mailer_class = mailer
          else
            raise NonInferrableMailerError.new(mailer)
          end
        end

        def mailer_class
          if mailer = _mailer_class
            mailer
          else
            tests determine_default_mailer(name)
          end
        end

        def determine_default_mailer(name)
          mailer = determine_constant_from_test_name(name) do |constant|
            Class === constant && constant < ActionMailer::Base
          end
          raise NonInferrableMailerError.new(name) if mailer.nil?
          mailer
        end
      end

      # Reads the fixture file for the given mailer.
      #
      # This is useful when testing mailers by being able to write the body of
      # an email inside a fixture. See the testing guide for a concrete example:
      # https://guides.rubyonrails.org/testing.html#revenge-of-the-fixtures
      def read_fixture(action)
        IO.readlines(File.join(Rails.root, "test", "fixtures", self.class.mailer_class.name.underscore, action))
      end

      # Assert that a Mail instance has a part matching the content type.
      # If the Mail is multipart, extract and decode the appropriate part. Yield the decoded part to the block.
      #
      # By default, assert against the last delivered Mail.
      #
      #   UsersMailer.create(user).deliver_now
      #   assert_part :text do |text|
      #     assert_includes text, "Welcome, #{user.email}"
      #   end
      #   assert_part :html do |html|
      #     assert_dom html.root, "h1", text: "Welcome, #{user.email}"
      #   end
      #
      # Assert against a Mail instance when provided
      #
      #   mail = UsersMailer.create(user)
      #   assert_part :text, mail do |text|
      #     assert_includes text, "Welcome, #{user.email}"
      #   end
      #   assert_part :html, mail do |html|
      #     assert_dom html.root, "h1", text: "Welcome, #{user.email}"
      #   end
      def assert_part(content_type, mail = last_delivered_mail!)
        mime_type = Mime[content_type]
        part = [*mail.parts, mail].find { |part| mime_type.match?(part.mime_type) }
        decoder = _decoders[mime_type]

        assert_not_nil part, "expected part matching #{mime_type} in #{mail.inspect}"

        yield decoder.call(part.decoded) if block_given?
      end

      # Assert that a Mail instance does not have a part with a matching MIME type
      #
      # By default, assert against the last delivered Mail.
      #
      #   UsersMailer.create(user).deliver_now
      #
      #   assert_no_part :html
      #   assert_no_part :text
      def assert_no_part(content_type, mail = last_delivered_mail!)
        mime_type = Mime[content_type]
        part = [*mail.parts, mail].find { |part| mime_type.match?(part.mime_type) }

        assert_nil part, "expected no part matching #{mime_type} in #{mail.inspect}"
      end

      private
        def initialize_test_deliveries
          set_delivery_method :test
          @old_perform_deliveries = ActionMailer::Base.perform_deliveries
          ActionMailer::Base.perform_deliveries = true
          ActionMailer::Base.deliveries.clear
        end

        def restore_test_deliveries
          restore_delivery_method
          ActionMailer::Base.perform_deliveries = @old_perform_deliveries
        end

        def set_delivery_method(method)
          @old_delivery_method = ActionMailer::Base.delivery_method
          ActionMailer::Base.delivery_method = method
        end

        def restore_delivery_method
          ActionMailer::Base.deliveries.clear
          ActionMailer::Base.delivery_method = @old_delivery_method
        end

        def set_expected_mail
          @expected = Mail.new
          @expected.content_type ["text", "plain", { "charset" => charset }]
          @expected.mime_version = "1.0"
        end

        def charset
          "UTF-8"
        end

        def encode(subject)
          Mail::Encodings.q_value_encode(subject, charset)
        end

        def last_delivered_mail
          self.class.mailer_class.deliveries.last
        end

        def last_delivered_mail!
          last_delivered_mail.tap do |mail|
            flunk "No e-mail in delivery list" if mail.nil?
          end
        end
    end

    include Behavior
  end
end
