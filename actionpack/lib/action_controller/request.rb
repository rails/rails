module ActionController
  class Request #:nodoc:
    # Returns both GET and POST parameters in a single hash.
    def parameters
      request_parameters.update(query_parameters)
    end
  end
end