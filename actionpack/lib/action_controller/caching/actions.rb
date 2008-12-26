require 'set'

module ActionController #:nodoc:
  module Caching
    # Action caching is similar to page caching by the fact that the entire output of the response is cached, but unlike page caching,
    # every request still goes through the Action Pack. The key benefit of this is that filters are run before the cache is served, which
    # allows for authentication and other restrictions on whether someone is allowed to see the cache. Example:
    #
    #   class ListsController < ApplicationController
    #     before_filter :authenticate, :except => :public
    #     caches_page   :public
    #     caches_action :index, :show, :feed
    #   end
    #
    # In this example, the public action doesn't require authentication, so it's possible to use the faster page caching method. But both the
    # show and feed action are to be shielded behind the authenticate filter, so we need to implement those as action caches.
    #
    # Action caching internally uses the fragment caching and an around filter to do the job. The fragment cache is named according to both
    # the current host and the path. So a page that is accessed at http://david.somewhere.com/lists/show/1 will result in a fragment named
    # "david.somewhere.com/lists/show/1". This allows the cacher to differentiate between "david.somewhere.com/lists/" and
    # "jamis.somewhere.com/lists/" -- which is a helpful way of assisting the subdomain-as-account-key pattern.
    #
    # Different representations of the same resource, e.g. <tt>http://david.somewhere.com/lists</tt> and <tt>http://david.somewhere.com/lists.xml</tt>
    # are treated like separate requests and so are cached separately. Keep in mind when expiring an action cache that <tt>:action => 'lists'</tt> is not the same
    # as <tt>:action => 'list', :format => :xml</tt>.
    #
    # You can set modify the default action cache path by passing a :cache_path option.  This will be passed directly to ActionCachePath.path_for.  This is handy
    # for actions with multiple possible routes that should be cached differently.  If a block is given, it is called with the current controller instance.
    #
    # And you can also use :if (or :unless) to pass a Proc that specifies when the action should be cached.
    #
    # Finally, if you are using memcached, you can also pass :expires_in.
    #
    #   class ListsController < ApplicationController
    #     before_filter :authenticate, :except => :public
    #     caches_page   :public
    #     caches_action :index, :if => Proc.new { |c| !c.request.format.json? } # cache if is not a JSON request
    #     caches_action :show, :cache_path => { :project => 1 }, :expires_in => 1.hour
    #     caches_action :feed, :cache_path => Proc.new { |controller|
    #       controller.params[:user_id] ?
    #         controller.send(:user_list_url, controller.params[:user_id], controller.params[:id]) :
    #         controller.send(:list_url, controller.params[:id]) }
    #   end
    #
    # If you pass :layout => false, it will only cache your action content. It is useful when your layout has dynamic information.
    #
    module Actions
      def self.included(base) #:nodoc:
        base.extend(ClassMethods)
          base.class_eval do
            attr_accessor :rendered_action_cache, :action_cache_path
          end
      end

      module ClassMethods
        # Declares that +actions+ should be cached.
        # See ActionController::Caching::Actions for details.
        def caches_action(*actions)
          return unless cache_configured?
          options = actions.extract_options!
          filter_options = { :only => actions, :if => options.delete(:if), :unless => options.delete(:unless) }

          cache_filter = ActionCacheFilter.new(:layout => options.delete(:layout), :cache_path => options.delete(:cache_path), :store_options => options)
          around_filter(cache_filter, filter_options)
        end
      end

      protected
        def expire_action(options = {})
          return unless cache_configured?

          if options[:action].is_a?(Array)
            options[:action].dup.each do |action|
              expire_fragment(ActionCachePath.path_for(self, options.merge({ :action => action }), false))
            end
          else
            expire_fragment(ActionCachePath.path_for(self, options, false))
          end
        end

      class ActionCacheFilter #:nodoc:
        def initialize(options, &block)
          @options = options
        end

        def before(controller)
          cache_path = ActionCachePath.new(controller, path_options_for(controller, @options.slice(:cache_path)))
          if cache = controller.read_fragment(cache_path.path, @options[:store_options])
            controller.rendered_action_cache = true
            set_content_type!(controller, cache_path.extension)
            options = { :text => cache }
            options.merge!(:layout => true) if cache_layout?
            controller.__send__(:render, options)
            false
          else
            controller.action_cache_path = cache_path
          end
        end

        def after(controller)
          return if controller.rendered_action_cache || !caching_allowed(controller)
          action_content = cache_layout? ? content_for_layout(controller) : controller.response.body
          controller.write_fragment(controller.action_cache_path.path, action_content, @options[:store_options])
        end

        private
          def set_content_type!(controller, extension)
            controller.response.content_type = Mime::Type.lookup_by_extension(extension).to_s if extension
          end

          def path_options_for(controller, options)
            ((path_options = options[:cache_path]).respond_to?(:call) ? path_options.call(controller) : path_options) || {}
          end

          def caching_allowed(controller)
            controller.request.get? && controller.response.status.to_i == 200
          end

          def cache_layout?
            @options[:layout] == false
          end

          def content_for_layout(controller)
            controller.response.layout && controller.response.template.instance_variable_get('@cached_content_for_layout')
          end
      end

      class ActionCachePath
        attr_reader :path, :extension

        class << self
          def path_for(controller, options, infer_extension=true)
            new(controller, options, infer_extension).path
          end
        end
        
        # When true, infer_extension will look up the cache path extension from the request's path & format.
        # This is desirable when reading and writing the cache, but not when expiring the cache -  expire_action should expire the same files regardless of the request format.
        def initialize(controller, options = {}, infer_extension=true)
          if infer_extension and options.is_a? Hash
            request_extension = extract_extension(controller.request)
            options = options.reverse_merge(:format => request_extension)
          end
          path = controller.url_for(options).split('://').last
          normalize!(path)
          if infer_extension
            @extension = request_extension
            add_extension!(path, @extension)
          end
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
            extension = request.path[/^[^.]+\.(.+)$/, 1]

            # If there's no extension in the path, check request.format
            if extension.nil?
              extension = request.cache_format
            end
            extension
          end
      end
    end
  end
end
