require "action_dispatch/http/request"

module ActionDispatch
  # ActionDispatch::ParamsParser works for all the requests having any Content-Length
  # (like POST). It takes raw data from the request and puts it through the parser
  # that is picked based on Content-Type header.
  #
  # In case of any error while parsing data ParamsParser::ParseError is raised.
  class ParamsParser
    # Raised when raw data from the request cannot be parsed by the parser
    # defined for request's content mime type.
    class ParseError < StandardError

      def initialize(message = nil, original_exception = nil)
        if message
          ActiveSupport::Deprecation.warn("Passing #message is deprecated and has no effect. " \
                                          "#{self.class} will automatically capture the message " \
                                          "of the original exception.", caller)
        end

        if original_exception
          ActiveSupport::Deprecation.warn("Passing #original_exception is deprecated and has no effect. " \
                                          "Exceptions will automatically capture the original exception.", caller)
        end

        super($!.message)
      end

      def original_exception
        ActiveSupport::Deprecation.warn("#original_exception is deprecated. Use #cause instead.", caller)
        cause
      end
    end

    # Create a new +ParamsParser+ middleware instance.
    #
    # The +parsers+ argument can take Hash of parsers where key is identifying
    # content mime type, and value is a lambda that is going to process data.
    def self.new(app, parsers = {})
      ActiveSupport::Deprecation.warn("ActionDispatch::ParamsParser is deprecated and will be removed in Rails 5.1. Configure the parameter parsing in ActionDispatch::Request.parameter_parsers.")
      parsers = parsers.transform_keys { |key| key.respond_to?(:symbol) ? key.symbol : key }
      ActionDispatch::Request.parameter_parsers = ActionDispatch::Request::DEFAULT_PARSERS.merge(parsers)
      app
    end
  end
end
