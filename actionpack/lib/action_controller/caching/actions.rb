require 'set'

module ActionController #:nodoc:
  module Caching
    # Action caching is similar to page caching by the fact that the entire output of the response is
    # cached, but unlike page caching, every request still goes through the Action Pack. The key benefit
    # of this is that filters are run before the cache is served, which allows for authentication and other
    # restrictions on whether someone is allowed to see the cache. Example:
    #
    #   class ListsController < ApplicationController
    #     before_filter :authenticate, :except => :public
    #     caches_page   :public
    #     caches_action :index, :show, :feed
    #   end
    #
    # In this example, the public action doesn't require authentication, so it's possible to use the faster
    # page caching method. But both the show and feed action are to be shielded behind the authenticate
    # filter, so we need to implement those as action caches.
    #
    # Action caching internally uses the fragment caching and an around filter to do the job. The fragment
    # cache is named according to both the current host and the path. So a page that is accessed at
    # http://david.somewhere.com/lists/show/1 will result in a fragment named
    # "david.somewhere.com/lists/show/1". This allows the cacher to differentiate between
    # "david.somewhere.com/lists/" and
    # "jamis.somewhere.com/lists/" -- which is a helpful way of assisting the subdomain-as-account-key
    # pattern.
    #
    # Different representations of the same resource, e.g. <tt>http://david.somewhere.com/lists</tt> and
    # <tt>http://david.somewhere.com/lists.xml</tt>
    # are treated like separate requests and so are cached separately. Keep in mind when expiring an
    # action cache that <tt>:action => 'lists'</tt> is not the same as
    # <tt>:action => 'list', :format => :xml</tt>.
    #
    # You can set modify the default action cache path by passing a :cache_path option.  This will be
    # passed directly to ActionCachePath.path_for.  This is handy for actions with multiple possible
    # routes that should be cached differently.  If a block is given, it is called with the current
    # controller instance.
    #
    # And you can also use :if (or :unless) to pass a Proc that specifies when the action should
    # be cached.
    #
    # Finally, if you are using memcached, you can also pass :expires_in.
    #
    #   class ListsController < ApplicationController
    #     before_filter :authenticate, :except => :public
    #     caches_page   :public
    #     caches_action :index, :if => proc { |c| !c.request.format.json? } # cache if is not a JSON request
    #     caches_action :show, :cache_path => { :project => 1 }, :expires_in => 1.hour
    #     caches_action :feed, :cache_path => proc { |controller|
    #       controller.params[:user_id] ?
    #         controller.send(:user_list_url, controller.params[:user_id], controller.params[:id]) :
    #         controller.send(:list_url, controller.params[:id]) }
    #   end
    #
    # If you pass :layout => false, it will only cache your action content. It is useful when your
    # layout has dynamic information.
    #
    module Actions
      extend ActiveSupport::Concern

      included do
        attr_accessor :rendered_action_cache, :action_cache_path
      end

      module ClassMethods
        # Declares that +actions+ should be cached.
        # See ActionController::Caching::Actions for details.
        def caches_action(*actions)
          return unless cache_configured?
          options = actions.extract_options!
          filter_options = options.extract!(:if, :unless).merge(:only => actions)
          cache_options  = options.extract!(:layout, :cache_path).merge(:store_options => options)

          around_filter ActionCacheFilter.new(cache_options), filter_options
        end
      end

      def _render_cache_fragment(cache, extension, layout)
        self.rendered_action_cache = true
        response.content_type = Mime[extension].to_s if extension
        options = { :text => cache }
        options.merge!(:layout => true) if layout
        render options
      end

      def _save_fragment(name, layout, options)
        return unless caching_allowed?

        content = layout ? view_context.content_for(:layout) : response_body
        write_fragment(name, content, options)
      end

      protected
        def expire_action(options = {})
          return unless cache_configured?

          actions = options[:action]
          if actions.is_a?(Array)
            actions.each {|action| expire_action(options.merge(:action => action)) }
          else
            expire_fragment(ActionCachePath.path_for(self, options, false))
          end
        end

      class ActionCacheFilter #:nodoc:
        def initialize(options, &block)
          @cache_path, @store_options, @layout =
            options.values_at(:cache_path, :store_options, :layout)
        end

        def filter(controller)
          path_options = @cache_path.respond_to?(:call) ? @cache_path.call(controller) : @cache_path
          cache_path = ActionCachePath.new(controller, path_options || {})

          if cache = controller.read_fragment(cache_path.path, @store_options)
            controller._render_cache_fragment(cache, cache_path.extension, @layout == false)
          else
            yield
            controller._save_fragment(cache_path.path, @layout == false, @store_options)
          end
        end
      end

      class ActionCachePath
        attr_reader :path, :extension

        class << self
          def path_for(controller, options, infer_extension = true)
            new(controller, options, infer_extension).path
          end
        end

        # If +infer_extension+ is true, the cache path extension is looked up from the request's
        # path & format. This is desirable when reading and writing the cache, but not when
        # expiring the cache - expire_action should expire the same files regardless of the
        # request format.
        def initialize(controller, options = {}, infer_extension = true)
          if infer_extension
            extract_extension(controller.request)
            options = options.reverse_merge(:format => @extension) if options.is_a?(Hash)
          end

          path = controller.url_for(options).split('://').last
          normalize!(path)
          add_extension!(path, @extension)
          @path = URI.unescape(path)
        end

      private
        def normalize!(path)
          path << 'index' if path[-1] == ?/
        end

        def add_extension!(path, extension)
          path << ".#{extension}" if extension and !path.ends_with?(extension)
        end

        def extract_extension(request)
          # Don't want just what comes after the last '.' to accommodate multi part extensions
          # such as tar.gz.
          @extension = request.path[/^[^.]+\.(.+)$/, 1] || request.cache_format
        end
      end
    end
  end
end
