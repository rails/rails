# frozen_string_literal: true

module ActionMailer #:nodoc:
  # Provides +rescue_from+ for mailers. Wraps mailer action processing,
  # mail job processing, and mail delivery.
  module Rescuable
    extend ActiveSupport::Concern
    include ActiveSupport::Rescuable

    class_methods do
      def handle_exception(exception) #:nodoc:
        rescue_with_handler(exception) || raise(exception)
      end
    end

    def handle_exceptions #:nodoc:
      yield
    rescue => exception
      rescue_with_handler(exception) || raise
    end

    private
      def process(*)
        handle_exceptions do
          super
        end
      end
  end
end
