module ActionController
  module Session
    def session
      @_request.session
    end

    def reset_session
      @_request.reset_session
    end
  end
end
