module ActionController
  module Testing
    extend ActiveSupport::Concern

    include RackDelegation

    # TODO : Rewrite tests using controller.headers= to use Rack env
    def headers=(new_headers)
      @_response ||= ActionDispatch::Response.new
      @_response.headers.replace(new_headers)
    end

    # Behavior specific to functional tests
    module Functional # :nodoc:
      def set_response!(request)
      end

      def recycle!
        @_url_options = nil
        self.formats = nil
        self.params = nil
      end
    end

    module ClassMethods
      def before_filters
        _process_action_callbacks.find_all{|x| x.kind == :before}.map{|x| x.name}
      end
    end
  end
end
