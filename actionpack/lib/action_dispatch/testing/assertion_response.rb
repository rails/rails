module ActionDispatch
  # This is a class that abstracts away an asserted response.
  # It purposely does not inherit from Response, because it doesn't need it.
  # That means it does not have headers or a body.
  #
  # As an input to the initializer, we take a Fixnum, a String, or a Symbol.
  # If it's a Fixnum or String, we figure out what its symbolized name.
  # If it's a Symbol, we figure out what its corresponding code is.
  # The resulting code will be a Fixnum, for real HTTP codes, and it will
  # be a String for the pseudo-HTTP codes, such as:
  #   :success, :missing, :redirect and :error
  class AssertionResponse
    attr_reader :code, :name

    GENERIC_RESPONSE_CODES = { # :nodoc:
      success: "2XX",
      missing: "404",
      redirect: "3XX",
      error: "5XX"
    }

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
      GENERIC_RESPONSE_CODES[name] || Rack::Utils::SYMBOL_TO_STATUS_CODE[name]
    end

    def name_from_code(code)
      GENERIC_RESPONSE_CODES.invert[code] || Rack::Utils::HTTP_STATUS_CODES[code]
    end
  end
end
