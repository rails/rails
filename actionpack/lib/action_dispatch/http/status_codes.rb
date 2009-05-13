require 'active_support/inflector'

module ActionDispatch
  module StatusCodes #:nodoc:
    STATUS_CODES = Rack::Utils::HTTP_STATUS_CODES.merge({
      102 => "Processing",
      207 => "Multi-Status",
      226 => "IM Used",
      422 => "Unprocessable Entity",
      423 => "Locked",
      424 => "Failed Dependency",
      426 => "Upgrade Required",
      507 => "Insufficient Storage",
      510 => "Not Extended"
    }).freeze

    # Provides a symbol-to-fixnum lookup for converting a symbol (like
    # :created or :not_implemented) into its corresponding HTTP status
    # code (like 200 or 501).
    SYMBOL_TO_STATUS_CODE = STATUS_CODES.inject({}) { |hash, (code, message)|
      hash[ActiveSupport::Inflector.underscore(message.gsub(/ /, "")).to_sym] = code
      hash
    }.freeze

    private
      # Given a status parameter, determine whether it needs to be converted
      # to a string. If it is a fixnum, use the STATUS_CODES hash to lookup
      # the default message. If it is a symbol, use the SYMBOL_TO_STATUS_CODE
      # hash to convert it.
      def interpret_status(status)
        case status
        when Fixnum then
          "#{status} #{STATUS_CODES[status]}".strip
        when Symbol then
          interpret_status(SYMBOL_TO_STATUS_CODE[status] ||
            "500 Unknown Status #{status.inspect}")
        else
          status.to_s
        end
      end
  end
end
