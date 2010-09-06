module ActionDispatch
  # Integration test methods such as ActionDispatch::Integration::Session#get
  # and ActionDispatch::Integration::Session#post return objects of class
  # TestResponse, which represent the HTTP response results of the requested
  # controller actions.
  #
  # See Response for more information on controller response objects.
  class TestResponse < Response
    def self.from_response(response)
      new.tap do |resp|
        resp.status  = response.status
        resp.headers = response.headers
        resp.body    = response.body
      end
    end

    # Was the response successful?
    def success?
      (200..299).include?(response_code)
    end

    # Was the URL not found?
    def missing?
      response_code == 404
    end

    # Were we redirected?
    def redirect?
      (300..399).include?(response_code)
    end

    # Was there a server-side error?
    def error?
      (500..599).include?(response_code)
    end
    alias_method :server_error?, :error?

    # Was there a client client?
    def client_error?
      (400..499).include?(response_code)
    end
  end
end
