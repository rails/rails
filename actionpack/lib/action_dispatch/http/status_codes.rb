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
  end
end
