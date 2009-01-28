module ActionController
  module StatusCodes #:nodoc:
    # Defines the standard HTTP status codes, by integer, with their
    # corresponding default message texts.
    # Source: http://www.iana.org/assignments/http-status-codes
    STATUS_CODES = {
      100 => "Continue",
      101 => "Switching Protocols",
      102 => "Processing",

      200 => "OK",
      201 => "Created",
      202 => "Accepted",
      203 => "Non-Authoritative Information",
      204 => "No Content",
      205 => "Reset Content",
      206 => "Partial Content",
      207 => "Multi-Status",
      226 => "IM Used",

      300 => "Multiple Choices",
      301 => "Moved Permanently",
      302 => "Found",
      303 => "See Other",
      304 => "Not Modified",
      305 => "Use Proxy",
      307 => "Temporary Redirect",

      400 => "Bad Request",
      401 => "Unauthorized",
      402 => "Payment Required",
      403 => "Forbidden",
      404 => "Not Found",
      405 => "Method Not Allowed",
      406 => "Not Acceptable",
      407 => "Proxy Authentication Required",
      408 => "Request Timeout",
      409 => "Conflict",
      410 => "Gone",
      411 => "Length Required",
      412 => "Precondition Failed",
      413 => "Request Entity Too Large",
      414 => "Request-URI Too Long",
      415 => "Unsupported Media Type",
      416 => "Requested Range Not Satisfiable",
      417 => "Expectation Failed",
      422 => "Unprocessable Entity",
      423 => "Locked",
      424 => "Failed Dependency",
      426 => "Upgrade Required",

      500 => "Internal Server Error",
      501 => "Not Implemented",
      502 => "Bad Gateway",
      503 => "Service Unavailable",
      504 => "Gateway Timeout",
      505 => "HTTP Version Not Supported",
      507 => "Insufficient Storage",
      510 => "Not Extended"
    }

    # Provides a symbol-to-fixnum lookup for converting a symbol (like
    # :created or :not_implemented) into its corresponding HTTP status
    # code (like 200 or 501).
    SYMBOL_TO_STATUS_CODE = STATUS_CODES.inject({}) do |hash, (code, message)|
      hash[message.gsub(/ /, "").underscore.to_sym] = code
      hash
    end

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
    private :interpret_status

  end
end