require 'active_support/test_case'

module ActionMailer
  class NonInferrableMailerError < ::StandardError
    def initialize(name)
      super "Unable to determine the mailer to test from #{name}. " +
        "You'll need to specify it using tests YourMailer in your " +
        "test case definition"
    end
  end

  class TestCase < ActiveSupport::TestCase
    module Behavior
      extend ActiveSupport::Concern

      include ActiveSupport::Testing::ConstantLookup
      include TestHelper

      included do
        class_attribute :_mailer_class
        setup :initialize_test_deliveries
        setup :set_expected_mail
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
          if mailer = self._mailer_class
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

      protected

        def initialize_test_deliveries
          ActionMailer::Base.delivery_method = :test
          ActionMailer::Base.perform_deliveries = true
          ActionMailer::Base.deliveries.clear
        end

        def set_expected_mail
          @expected = Mail.new
          @expected.content_type ["text", "plain", { "charset" => charset }]
          @expected.mime_version = '1.0'
        end

      private

        def charset
          "UTF-8"
        end

        def encode(subject)
          Mail::Encodings.q_value_encode(subject, charset)
        end

        def read_fixture(action)
          IO.readlines(File.join(Rails.root, 'test', 'fixtures', self.class.mailer_class.name.underscore, action))
        end
    end

    include Behavior
  end
end
