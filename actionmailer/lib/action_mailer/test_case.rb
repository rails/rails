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
    include Quoting, TestHelper

    setup :initialize_test_deliveries
    setup :set_expected_mail

    class << self
      def tests(mailer)
        write_inheritable_attribute(:mailer_class, mailer)
      end

      def mailer_class
        if mailer = read_inheritable_attribute(:mailer_class)
          mailer
        else
          tests determine_default_mailer(name)
        end
      end

      def determine_default_mailer(name)
        name.sub(/Test$/, '').constantize
      rescue NameError => e
        raise NonInferrableMailerError.new(name)
      end
    end

    protected
      def initialize_test_deliveries
        ActionMailer::Base.delivery_method = :test
        ActionMailer::Base.perform_deliveries = true
        ActionMailer::Base.deliveries = []
      end

      def set_expected_mail
        @expected = TMail::Mail.new
        @expected.set_content_type "text", "plain", { "charset" => charset }
        @expected.mime_version = '1.0'
      end

    private
      def charset
        "utf-8"
      end

      def encode(subject)
        quoted_printable(subject, charset)
      end

      def read_fixture(action)
        IO.readlines(File.join(RAILS_ROOT, 'test', 'fixtures', self.class.mailer_class.name.underscore, action))
      end
  end
end
