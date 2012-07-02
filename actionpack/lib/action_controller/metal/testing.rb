module ActionController
  module Testing
    extend ActiveSupport::Concern

    include RackDelegation

    # This gets included on the second request. We only want to modify this
    # behavior on the second request. Ugh.
    module Recycled # :nodoc:
      def set_response!(request)
      end

      def process(name)
        ret = super
        if cookies = @_request.env['action_dispatch.cookies']
          cookies.write(@_response)
        end
        @_response.prepare!
        ret
      end

      def recycled?
        true
      end
    end

    def recycled? # :nodoc:
      false
    end

    def recycle!
      @_url_options = nil
      extend Recycled unless recycled?
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
