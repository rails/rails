# frozen_string_literal: true

module ActionDispatch
  # This is a class that abstracts away an asserted response. It purposely
  # does not inherit from Response because it doesn't need it. That means it
  # does not have headers or a body.
  class AssertionResponse
    attr_reader :code, :name

    GENERIC_RESPONSE_CODES = { # :nodoc:
      success: "2XX",
      missing: "404",
      redirect: "3XX",
      error: "5XX"
    }

    # Accepts a specific response status code as an Integer (404) or String
    # ('404') or a response status range as a Symbol pseudo-code (:success,
    # indicating any 200-299 status code).
    def initialize(code_or_name)
      if code_or_name.is_a?(Symbol)
        @name = code_or_name
        @code = code_from_name(code_or_name)
      else
        @name = name_from_code(code_or_name)
        @code = code_or_name
      end

      raise ArgumentError, "Invalid response name: #{name}" if @code.nil?
      raise ArgumentError, "Invalid response code: #{code}" if @name.nil?
    end

    def code_and_name
      "#{code}: #{name}"
    end

    private
      def code_from_name(name)
        GENERIC_RESPONSE_CODES[name] || Rack::Utils.status_code(name)
      end

      def name_from_code(code)
        GENERIC_RESPONSE_CODES.invert[code] || Rack::Utils::HTTP_STATUS_CODES[code]
      end
  end
end
