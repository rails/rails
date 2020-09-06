# frozen_string_literal: true

require 'active_support/test_case'
require 'rails-dom-testing'

module ActionMailer
  class NonInferrableMailerError < ::StandardError
    def initialize(name)
      super "Unable to determine the mailer to test from #{name}. " \
        "You'll need to specify it using tests YourMailer in your " \
        'test case definition'
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
          @expected.content_type ['text', 'plain', { 'charset' => charset }]
          @expected.mime_version = '1.0'
        end

        def charset
          'UTF-8'
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
