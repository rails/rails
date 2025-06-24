# frozen_string_literal: true

# :markup: markdown

module ActionDispatch
  module Routing
    # # Action Dispatch Routing UrlFor
    #
    # In `config/routes.rb` you define URL-to-controller mappings, but the reverse
    # is also possible: a URL can be generated from one of your routing definitions.
    # URL generation functionality is centralized in this module.
    #
    # See ActionDispatch::Routing for general information about routing and
    # `config/routes.rb`.
    #
    # **Tip:** If you need to generate URLs from your models or some other place,
    # then ActionDispatch::Routing::UrlFor is what you're looking for. Read on for
    # an introduction. In general, this module should not be included on its own, as
    # it is usually included by `url_helpers` (as in
    # `Rails.application.routes.url_helpers`).
    #
    # ## URL generation from parameters
    #
    # As you may know, some functions, such as `ActionController::Base#url_for` and
    # ActionView::Helpers::UrlHelper#link_to, can generate URLs given a set of
    # parameters. For example, you've probably had the chance to write code like
    # this in one of your views:
    #
    #     <%= link_to('Click here', controller: 'users',
    #             action: 'new', message: 'Welcome!') %>
    #     # => <a href="/users/new?message=Welcome%21">Click here</a>
    #
    # `link_to`, and all other functions that require URL generation functionality,
    # actually use ActionDispatch::Routing::UrlFor under the hood. And in
    # particular, they use the ActionDispatch::Routing::UrlFor#url_for method. One
    # can generate the same path as the above example by using the following code:
    #
    #     include ActionDispatch::Routing::UrlFor
    #     url_for(controller: 'users',
    #             action: 'new',
    #             message: 'Welcome!',
    #             only_path: true)
    #     # => "/users/new?message=Welcome%21"
    #
    # Notice the `only_path: true` part. This is because UrlFor has no information
    # about the website hostname that your Rails app is serving. So if you want to
    # include the hostname as well, then you must also pass the `:host` argument:
    #
    #     include UrlFor
    #     url_for(controller: 'users',
    #             action: 'new',
    #             message: 'Welcome!',
    #             host: 'www.example.com')
    #     # => "http://www.example.com/users/new?message=Welcome%21"
    #
    # By default, all controllers and views have access to a special version of
    # `url_for`, that already knows what the current hostname is. So if you use
    # `url_for` in your controllers or your views, then you don't need to explicitly
    # pass the `:host` argument.
    #
    # For convenience, mailers also include ActionDispatch::Routing::UrlFor. So
    # within mailers, you can use url_for. However, mailers cannot access incoming
    # web requests in order to derive hostname information, so you have to provide
    # the `:host` option or set the default host using `default_url_options`. For
    # more information on url_for in mailers see the ActionMailer::Base
    # documentation.
    #
    # ## URL generation for named routes
    #
    # UrlFor also allows one to access methods that have been auto-generated from
    # named routes. For example, suppose that you have a 'users' resource in your
    # `config/routes.rb`:
    #
    #     resources :users
    #
    # This generates, among other things, the method `users_path`. By default, this
    # method is accessible from your controllers, views, and mailers. If you need to
    # access this auto-generated method from other places (such as a model), then
    # you can do that by including `Rails.application.routes.url_helpers` in your
    # class:
    #
    #     class User < ActiveRecord::Base
    #       include Rails.application.routes.url_helpers
    #
    #       def base_uri
    #         user_path(self)
    #       end
    #     end
    #
    #     User.find(1).base_uri # => "/users/1"
    #
    module UrlFor
      extend ActiveSupport::Concern
      include PolymorphicRoutes

      included do
        unless method_defined?(:default_url_options)
          # Including in a class uses an inheritable hash. Modules get a plain hash.
          if respond_to?(:class_attribute)
            class_attribute :default_url_options
          else
            mattr_writer :default_url_options
          end

          self.default_url_options = {}
        end

        include(*_url_for_modules) if respond_to?(:_url_for_modules)
      end

      def initialize(...)
        @_routes = nil
        super
      end

      # Hook overridden in controller to add request information with
      # `default_url_options`. Application logic should not go into url_options.
      def url_options
        default_url_options
      end

      # Generate a URL based on the options provided, `default_url_options`, and the
      # routes defined in `config/routes.rb`. The following options are supported:
      #
      # *   `:only_path` - If true, the relative URL is returned. Defaults to `false`.
      # *   `:protocol` - The protocol to connect to. Defaults to `"http"`.
      # *   `:host` - Specifies the host the link should be targeted at. If
      #     `:only_path` is false, this option must be provided either explicitly, or
      #     via `default_url_options`.
      # *   `:subdomain` - Specifies the subdomain of the link, using the `tld_length`
      #     to split the subdomain from the host. If false, removes all subdomains
      #     from the host part of the link.
      # *   `:domain` - Specifies the domain of the link, using the `tld_length` to
      #     split the domain from the host.
      # *   `:tld_length` - Number of labels the TLD id composed of, only used if
      #     `:subdomain` or `:domain` are supplied. Defaults to
      #     `ActionDispatch::Http::URL.tld_length`, which in turn defaults to 1.
      # *   `:port` - Optionally specify the port to connect to.
      # *   `:anchor` - An anchor name to be appended to the path.
      # *   `:params` - The query parameters to be appended to the path.
      # *   `:path_params` - The query parameters that will only be used for the named
      #     dynamic segments of path. If unused, they will be discarded.
      # *   `:trailing_slash` - If true, adds a trailing slash, as in
      #     `"/archive/2009/"`.
      # *   `:script_name` - Specifies application path relative to domain root. If
      #     provided, prepends application path.
      #
      #
      # Any other key (`:controller`, `:action`, etc.) given to `url_for` is forwarded
      # to the Routes module.
      #
      #     url_for controller: 'tasks', action: 'testing', host: 'somehost.org', port: '8080'
      #     # => 'http://somehost.org:8080/tasks/testing'
      #     url_for controller: 'tasks', action: 'testing', host: 'somehost.org', anchor: 'ok', only_path: true
      #     # => '/tasks/testing#ok'
      #     url_for controller: 'tasks', action: 'testing', trailing_slash: true
      #     # => 'http://somehost.org/tasks/testing/'
      #     url_for controller: 'tasks', action: 'testing', host: 'somehost.org', number: '33'
      #     # => 'http://somehost.org/tasks/testing?number=33'
      #     url_for controller: 'tasks', action: 'testing', host: 'somehost.org', script_name: "/myapp"
      #     # => 'http://somehost.org/myapp/tasks/testing'
      #     url_for controller: 'tasks', action: 'testing', host: 'somehost.org', script_name: "/myapp", only_path: true
      #     # => '/myapp/tasks/testing'
      #
      # Missing routes keys may be filled in from the current request's parameters
      # (e.g. `:controller`, `:action`, `:id`, and any other parameters that are
      # placed in the path). Given that the current action has been reached through
      # `GET /users/1`:
      #
      #     url_for(only_path: true)                        # => '/users/1'
      #     url_for(only_path: true, action: 'edit')        # => '/users/1/edit'
      #     url_for(only_path: true, action: 'edit', id: 2) # => '/users/2/edit'
      #
      # Notice that no `:id` parameter was provided to the first `url_for` call and
      # the helper used the one from the route's path. Any path parameter implicitly
      # used by `url_for` can always be overwritten like shown on the last `url_for`
      # calls.
      def url_for(options = nil)
        full_url_for(options)
      end

      def full_url_for(options = nil) # :nodoc:
        case options
        when nil
          _routes.url_for(url_options.symbolize_keys)
        when Hash, ActionController::Parameters
          route_name = options.delete :use_route
          merged_url_options = options.to_h.symbolize_keys.reverse_merge!(url_options)
          _routes.url_for(merged_url_options, route_name)
        when String
          options
        when Symbol
          HelperMethodBuilder.url.handle_string_call self, options
        when Array
          components = options.dup
          polymorphic_url(components, components.extract_options!)
        when Class
          HelperMethodBuilder.url.handle_class_call self, options
        else
          HelperMethodBuilder.url.handle_model_call self, options
        end
      end

      # Allows calling direct or regular named route.
      #
      #     resources :buckets
      #
      #     direct :recordable do |recording|
      #       route_for(:bucket, recording.bucket)
      #     end
      #
      #     direct :threadable do |threadable|
      #       route_for(:recordable, threadable.parent)
      #     end
      #
      # This maintains the context of the original caller on whether to return a path
      # or full URL, e.g:
      #
      #     threadable_path(threadable)  # => "/buckets/1"
      #     threadable_url(threadable)   # => "http://example.com/buckets/1"
      #
      def route_for(name, *args)
        public_send(:"#{name}_url", *args)
      end

      protected
        def optimize_routes_generation?
          _routes.optimize_routes_generation? && default_url_options.empty?
        end

      private
        def _with_routes(routes) # :doc:
          old_routes, @_routes = @_routes, routes
          yield
        ensure
          @_routes = old_routes
        end

        def _routes_context # :doc:
          self
        end
    end
  end
end
