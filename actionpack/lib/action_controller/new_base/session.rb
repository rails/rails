module ActionController
  module Session
    extend ActiveSupport::Concern

    include RackConvenience

    def session
      @_request.session
    end

    def reset_session
      @_request.reset_session
    end
  end
end
