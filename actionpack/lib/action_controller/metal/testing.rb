module ActionController
  module Testing
    extend ActiveSupport::Concern

    include RackDelegation

    def set_response!(request)
      super unless @_response
    end

    def recycle!
      @_url_options = nil
    end

    # TODO : Rewrite tests using controller.headers= to use Rack env
    def headers=(new_headers)
      @_response ||= ActionDispatch::Response.new
      @_response.headers.replace(new_headers)
    end

    module ClassMethods
      def before_filters
        _process_action_callbacks.find_all{|x| x.kind == :before}.map{|x| x.name}
      end
    end
  end
end
