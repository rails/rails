module ActionController
  module Session
    extend ActiveSupport::DependencyModule

    depends_on RackConvenience

    def session
      @_request.session
    end

    def reset_session
      @_request.reset_session
    end
  end
end
