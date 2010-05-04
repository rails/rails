require 'set'

module ActionController #:nodoc:
  module Caching
    # Action caching is similar to page caching by the fact that the entire
    # output of the response is cached, but unlike page caching, every
    # request still goes through the Action Pack. The key benefit
    # of this is that filters are run before the cache is served, which
    # allows for authentication and other restrictions on whether someone
    # is allowed to see the cache. Example:
    #
    #   class ListsController < ApplicationController
    #     before_filter :authenticate, :except => :public
    #     caches_page   :public
    #     caches_action :index, :show, :feed
    #   end
    #
    # In this example, the public action doesn't require authentication,
    # so it's possible to use the faster page caching method. But both
    # the show and feed action are to be shielded behind the authenticate
    # filter, so we need to implement those as action caches.
    #
    # Action caching internally uses the fragment caching and an around
    # filter to do the job. The fragment cache is named according to both
    # the current host and the path. So a page that is accessed at
    # http://david.somewhere.com/lists/show/1 will result in a fragment named
    # "david.somewhere.com/lists/show/1". This allows the cacher to
    # differentiate between "david.somewhere.com/lists/" and
    # "jamis.somewhere.com/lists/" -- which is a helpful way of assisting
    # the subdomain-as-account-key pattern.
    #
    # Different representations of the same resource, e.g.
    # <tt>http://david.somewhere.com/lists</tt> and
    # <tt>http://david.somewhere.com/lists.xml</tt>
    # are treated like separate requests and so are cached separately.
    # Keep in mind when expiring an action cache that
    # <tt>:action => 'lists'</tt> is not the same as
    # <tt>:action => 'list', :format => :xml</tt>.
    #
    # You can set modify the default action cache path by passing a
    # :cache_path option.  This will be passed directly to
    # ActionCachePath.path_for.  This is handy for actions with multiple
    # possible routes that should be cached differently.  If a block is
    # given, it is called with the current controller instance.
    #
    # And you can also use :if (or :unless) to pass a Proc that
    # specifies when the action should be cached.
    #
    # Finally, if you are using memcached, you can also pass :expires_in.
    #
    #   class ListsController < ApplicationController
    #     before_filter :authenticate, :except => :public
    #     caches_page   :public
    #     caches_action :index, :if => proc do |c|
    #       !c.request.format.json?  # cache if is not a JSON request
    #     end
    #
    #     caches_action :show, :cache_path => { :project => 1 },
    #       :expires_in => 1.hour
    #
    #     caches_action :feed, :cache_path => proc do |controller|
    #       if controller.params[:user_id]
    #         controller.send(:user_list_url,
    #           controller.params[:user_id], controller.params[:id])
    #       else
    #         controller.send(:list_url, controller.params[:id])
    #       end
    #     end
    #   end
    #
    # If you pass :layout => false, it will only cache your action
    # content. It is useful when your layout has dynamic information.
    #
    module Actions
      extend ActiveSupport::Concern

      module ClassMethods
        # Declares that +actions+ should be cached.
        # See ActionController::Caching::Actions for details.
        def caches_action(*actions)
          return unless cache_configured?
          options = actions.extract_options!
          options[:layout] = true unless options.key?(:layout)
          filter_options = options.extract!(:if, :unless).merge(:only => actions)
          cache_options  = options.extract!(:layout, :cache_path).merge(:store_options => options)

          around_filter ActionCacheFilter.new(cache_options), filter_options
        end
      end

      def _save_fragment(name, options)
        return unless caching_allowed?

        content = response_body
        content = content.join if content.is_a?(Array)

        write_fragment(name, content, options)
      end

    protected
      def expire_action(options = {})
        return unless cache_configured?

        actions = options[:action]
        if actions.is_a?(Array)
          actions.each {|action| expire_action(options.merge(:action => action)) }
        else
          expire_fragment(ActionCachePath.new(self, options, false).path)
        end
      end

      class ActionCacheFilter #:nodoc:
        def initialize(options, &block)
          @cache_path, @store_options, @cache_layout =
            options.values_at(:cache_path, :store_options, :layout)
        end

        def filter(controller)
          path_options = if @cache_path.respond_to?(:call)
            controller.instance_exec(controller, &@cache_path)
          else
            @cache_path
          end

          cache_path = ActionCachePath.new(controller, path_options || {})

          body = controller.read_fragment(cache_path.path, @store_options)

          unless body
            controller.action_has_layout = false unless @cache_layout
            yield
            controller.action_has_layout = true
            body = controller._save_fragment(cache_path.path, @store_options)
          end

          body = controller.render_to_string(:text => body, :layout => true) unless @cache_layout

          controller.response_body = body
          controller.content_type = Mime[cache_path.extension || :html]
        end
      end

      class ActionCachePath
        attr_reader :path, :extension

        # If +infer_extension+ is true, the cache path extension is looked up from the request's
        # path & format. This is desirable when reading and writing the cache, but not when
        # expiring the cache - expire_action should expire the same files regardless of the
        # request format.
        def initialize(controller, options = {}, infer_extension = true)
          if infer_extension
            @extension = controller.params[:format]
            options.reverse_merge!(:format => @extension) if options.is_a?(Hash)
          end

          path = controller.url_for(options).split(%r{://}).last
          @path = normalize!(path)
        end

      private
        def normalize!(path)
          path << 'index' if path[-1] == ?/
          path << ".#{extension}" if extension and !path.ends_with?(extension)
          URI.unescape(path)
        end
      end
    end
  end
end
