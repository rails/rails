module ActiveResource
  class ConnectionError < StandardError # :nodoc:
    attr_reader :response

    def initialize(response, message = nil)
      @response = response
      @message  = message
    end

    def to_s
      message = "Failed."
      message << "  Response code = #{response.code}." if response.respond_to?(:code)
      message << "  Response message = #{response.message}." if response.respond_to?(:message)
      message
    end
  end

  # Raised when a Timeout::Error occurs.
  class TimeoutError < ConnectionError
    def initialize(message)
      @message = message
    end
    def to_s; @message ;end
  end

  # Raised when a OpenSSL::SSL::SSLError occurs.
  class SSLError < ConnectionError
    def initialize(message)
      @message = message
    end
    def to_s; @message ;end
  end

  # 3xx Redirection
  class Redirection < ConnectionError # :nodoc:
    def to_s; response['Location'] ? "#{super} => #{response['Location']}" : super; end
  end

  # Raised when ...
  class MissingPrefixParam < ArgumentError; end # :nodoc:

  # 4xx Client Error
  class ClientError < ConnectionError; end # :nodoc:

  # 400 Bad Request
  class BadRequest < ClientError; end # :nodoc

  # 401 Unauthorized
  class UnauthorizedAccess < ClientError; end # :nodoc

  # 403 Forbidden
  class ForbiddenAccess < ClientError; end # :nodoc

  # 404 Not Found
  class ResourceNotFound < ClientError; end # :nodoc:

  # 409 Conflict
  class ResourceConflict < ClientError; end # :nodoc:

  # 410 Gone
  class ResourceGone < ClientError; end # :nodoc:

  # 5xx Server Error
  class ServerError < ConnectionError; end # :nodoc:

  # 405 Method Not Allowed
  class MethodNotAllowed < ClientError # :nodoc:
    def allowed_methods
      @response['Allow'].split(',').map { |verb| verb.strip.downcase.to_sym }
    end
  end
end
