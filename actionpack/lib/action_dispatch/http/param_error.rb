# frozen_string_literal: true

module ActionDispatch
  class ParamError < ActionDispatch::Http::Parameters::ParseError
    def initialize(message = nil)
      super
    end

    def self.===(other)
      super || (
        # Rack >= 3.1 tags every request-parsing error with Rack::BadRequest;
        # the explicit classes keep Rack 3.0 working.
        defined?(Rack::BadRequest) && Rack::BadRequest === other ||
        defined?(Rack::Utils::ParameterTypeError) && Rack::Utils::ParameterTypeError === other ||
        defined?(Rack::Utils::InvalidParameterError) && Rack::Utils::InvalidParameterError === other ||
        defined?(Rack::QueryParser::ParamsTooDeepError) && Rack::QueryParser::ParamsTooDeepError === other
      )
    end
  end

  class ParameterTypeError < ParamError
  end

  class InvalidParameterError < ParamError
  end

  class ParamsTooDeepError < ParamError
  end
end
