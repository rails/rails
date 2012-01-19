require 'active_support/inflector'

module ActionDispatch
  module Routing
    module Base
      # You can specify what Rails should route "/" to with the root method:
      #
      #   root :to => 'pages#main'
      #
      # For options, see +match+, as +root+ uses it internally.
      #
      # You should put the root route at the top of <tt>config/routes.rb</tt>,
      # because this means it will be matched first. As this is the most popular route
      # of most Rails applications, this is beneficial.
      def root(options = {})
        match '/', { :as => :root }.merge(options)
      end

      # Matches a url pattern to one or more routes. Any symbols in a pattern
      # are interpreted as url query parameters and thus available as +params+
      # in an action:
      #
      #   # sets :controller, :action and :id in params
      #   match ':controller/:action/:id'
      #
      # Two of these symbols are special, +:controller+ maps to the controller
      # and +:action+ to the controller's action. A pattern can also map
      # wildcard segments (globs) to params:
      #
      #   match 'songs/*category/:title' => 'songs#show'
      #
      #   # 'songs/rock/classic/stairway-to-heaven' sets
      #   #  params[:category] = 'rock/classic'
      #   #  params[:title] = 'stairway-to-heaven'
      #
      # When a pattern points to an internal route, the route's +:action+ and
      # +:controller+ should be set in options or hash shorthand. Examples:
      #
      #   match 'photos/:id' => 'photos#show'
      #   match 'photos/:id', :to => 'photos#show'
      #   match 'photos/:id', :controller => 'photos', :action => 'show'
      #
      # A pattern can also point to a +Rack+ endpoint i.e. anything that
      # responds to +call+:
      #
      #   match 'photos/:id' => lambda {|hash| [200, {}, "Coming soon"] }
      #   match 'photos/:id' => PhotoRackApp
      #   # Yes, controller actions are just rack endpoints
      #   match 'photos/:id' => PhotosController.action(:show)
      #
      # === Options
      #
      # Any options not seen here are passed on as params with the url.
      #
      # [:controller]
      #   The route's controller.
      #
      # [:action]
      #   The route's action.
      #
      # [:path]
      #   The path prefix for the routes.
      #
      # [:module]
      #   The namespace for :controller.
      #
      #     match 'path' => 'c#a', :module => 'sekret', :controller => 'posts'
      #     #=> Sekret::PostsController
      #
      #   See <tt>Scoping#namespace</tt> for its scope equivalent.
      #
      # [:as]
      #   The name used to generate routing helpers.
      #
      # [:via]
      #   Allowed HTTP verb(s) for route.
      #
      #      match 'path' => 'c#a', :via => :get
      #      match 'path' => 'c#a', :via => [:get, :post]
      #
      # [:to]
      #   Points to a +Rack+ endpoint. Can be an object that responds to
      #   +call+ or a string representing a controller's action.
      #
      #      match 'path', :to => 'controller#action'
      #      match 'path', :to => lambda { [200, {}, "Success!"] }
      #      match 'path', :to => RackApp
      #
      # [:on]
      #   Shorthand for wrapping routes in a specific RESTful context. Valid
      #   values are +:member+, +:collection+, and +:new+. Only use within
      #   <tt>resource(s)</tt> block. For example:
      #
      #      resource :bar do
      #        match 'foo' => 'c#a', :on => :member, :via => [:get, :post]
      #      end
      #
      #   Is equivalent to:
      #
      #      resource :bar do
      #        member do
      #          match 'foo' => 'c#a', :via => [:get, :post]
      #        end
      #      end
      #
      # [:constraints]
      #   Constrains parameters with a hash of regular expressions or an
      #   object that responds to <tt>matches?</tt>
      #
      #     match 'path/:id', :constraints => { :id => /[A-Z]\d{5}/ }
      #
      #     class Blacklist
      #       def matches?(request) request.remote_ip == '1.2.3.4' end
      #     end
      #     match 'path' => 'c#a', :constraints => Blacklist.new
      #
      #   See <tt>Scoping#constraints</tt> for more examples with its scope
      #   equivalent.
      #
      # [:defaults]
      #   Sets defaults for parameters
      #
      #     # Sets params[:format] to 'jpg' by default
      #     match 'path' => 'c#a', :defaults => { :format => 'jpg' }
      #
      #   See <tt>Scoping#defaults</tt> for its scope equivalent.
      #
      # [:anchor]
      #   Boolean to anchor a <tt>match</tt> pattern. Default is true. When set to
      #   false, the pattern matches any request prefixed with the given path.
      #
      #     # Matches any request starting with 'path'
      #     match 'path' => 'c#a', :anchor => false
      def match(path, options=nil)
      end

      # Mount a Rack-based application to be used within the application.
      #
      #   mount SomeRackApp, :at => "some_route"
      #
      # Alternatively:
      #
      #   mount(SomeRackApp => "some_route")
      #
      # For options, see +match+, as +mount+ uses it internally.
      #
      # All mounted applications come with routing helpers to access them.
      # These are named after the class specified, so for the above example
      # the helper is either +some_rack_app_path+ or +some_rack_app_url+.
      # To customize this helper's name, use the +:as+ option:
      #
      #   mount(SomeRackApp => "some_route", :as => "exciting")
      #
      # This will generate the +exciting_path+ and +exciting_url+ helpers
      # which can be used to navigate to this mounted app.
      def mount(app, options = nil)
        if options
          path = options.delete(:at)
        else
          options = app
          app, path = options.find { |k, v| k.respond_to?(:call) }
          options.delete(app) if app
        end

        raise "A rack application must be specified" unless path

        options[:as] ||= app_name(app)

        match(path, options.merge(:to => app, :anchor => false, :format => false))

        define_generate_prefix(app, options[:as])
        self
      end

      def default_url_options=(options)
        @set.default_url_options = options
      end
      alias_method :default_url_options, :default_url_options=

      def with_default_scope(scope, &block)
        scope(scope) do
          instance_exec(&block)
        end
      end

      private
        def app_name(app)
          return unless app.respond_to?(:routes)

          if app.respond_to?(:railtie_name)
            app.railtie_name
          else
            class_name = app.class.is_a?(Class) ? app.name : app.class.name
            ActiveSupport::Inflector.underscore(class_name).gsub("/", "_")
          end
        end

        def define_generate_prefix(app, name)
          return unless app.respond_to?(:routes) && app.routes.respond_to?(:define_mounted_helper)

          _route = @set.named_routes.routes[name.to_sym]
          _routes = @set
          app.routes.define_mounted_helper(name)
          app.routes.class_eval do
            define_method :_generate_prefix do |options|
              prefix_options = options.slice(*_route.segment_keys)
              # we must actually delete prefix segment keys to avoid passing them to next url_for
              _route.segment_keys.each { |k| options.delete(k) }
              prefix = _routes.url_helpers.send("#{name}_path", prefix_options)
              prefix = '' if prefix == '/'
              prefix
            end
          end
        end
    end
  end
end
