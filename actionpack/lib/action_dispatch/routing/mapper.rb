require 'erb'
require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/object/blank'
require 'active_support/inflector'

module ActionDispatch
  module Routing
    class Mapper
      class Constraints #:nodoc:
        def self.new(app, constraints, request = Rack::Request)
          if constraints.any?
            super(app, constraints, request)
          else
            app
          end
        end

        attr_reader :app

        def initialize(app, constraints, request)
          @app, @constraints, @request = app, constraints, request
        end

        def call(env)
          req = @request.new(env)

          @constraints.each { |constraint|
            if constraint.respond_to?(:matches?) && !constraint.matches?(req)
              return [ 404, {'X-Cascade' => 'pass'}, [] ]
            elsif constraint.respond_to?(:call) && !constraint.call(*constraint_args(constraint, req))
              return [ 404, {'X-Cascade' => 'pass'}, [] ]
            end
          }

          @app.call(env)
        end

        private
          def constraint_args(constraint, request)
            constraint.arity == 1 ? [request] : [request.symbolized_path_parameters, request]
          end
      end

      class Mapping #:nodoc:
        IGNORE_OPTIONS = [:to, :as, :via, :on, :constraints, :defaults, :only, :except, :anchor, :shallow, :shallow_path, :shallow_prefix]

        def initialize(set, scope, path, options)
          @set, @scope = set, scope
          @options = (@scope[:options] || {}).merge(options)
          @path = normalize_path(path)
          normalize_options!
        end

        def to_route
          [ app, conditions, requirements, defaults, @options[:as], @options[:anchor] ]
        end

        private

          def normalize_options!
            path_without_format = @path.sub(/\(\.:format\)$/, '')

            if using_match_shorthand?(path_without_format, @options)
              to_shorthand    = @options[:to].blank?
              @options[:to] ||= path_without_format[1..-1].sub(%r{/([^/]*)$}, '#\1')
            end

            @options.merge!(default_controller_and_action(to_shorthand))
          end

          # match "account/overview"
          def using_match_shorthand?(path, options)
            path && options.except(:via, :anchor, :to, :as).empty? && path =~ %r{^/[\w\/]+$}
          end

          def normalize_path(path)
            raise ArgumentError, "path is required" if path.blank?
            path = Mapper.normalize_path(path)

            if path.match(':controller')
              raise ArgumentError, ":controller segment is not allowed within a namespace block" if @scope[:module]

              # Add a default constraint for :controller path segments that matches namespaced
              # controllers with default routes like :controller/:action/:id(.:format), e.g:
              # GET /admin/products/show/1
              # => { :controller => 'admin/products', :action => 'show', :id => '1' }
              @options.reverse_merge!(:controller => /.+?/)
            end

            if @options[:format] == false
              @options.delete(:format)
              path
            elsif path.include?(":format")
              path
            else
              "#{path}(.:format)"
            end
          end

          def app
            Constraints.new(
              to.respond_to?(:call) ? to : Routing::RouteSet::Dispatcher.new(:defaults => defaults),
              blocks,
              @set.request_class
            )
          end

          def conditions
            { :path_info => @path }.merge(constraints).merge(request_method_condition)
          end

          def requirements
            @requirements ||= (@options[:constraints].is_a?(Hash) ? @options[:constraints] : {}).tap do |requirements|
              requirements.reverse_merge!(@scope[:constraints]) if @scope[:constraints]
              @options.each { |k, v| requirements[k] = v if v.is_a?(Regexp) }

              requirements.values.grep(Regexp).each do |requirement|
                if requirement.source =~ %r{\A(\\A|\^)|(\\Z|\\z|\$)\Z}
                  raise ArgumentError, "Regexp anchor characters are not allowed in routing requirements: #{requirement.inspect}"
                end
                if requirement.multiline?
                  raise ArgumentError, "Regexp multiline option not allowed in routing requirements: #{requirement.inspect}"
                end
              end
            end
          end

          def defaults
            @defaults ||= (@options[:defaults] || {}).tap do |defaults|
              defaults.reverse_merge!(@scope[:defaults]) if @scope[:defaults]
              @options.each { |k, v| defaults[k] = v unless v.is_a?(Regexp) || IGNORE_OPTIONS.include?(k.to_sym) }
            end
          end

          def default_controller_and_action(to_shorthand=nil)
            if to.respond_to?(:call)
              { }
            else
              if to.is_a?(String)
                controller, action = to.split('#')
              elsif to.is_a?(Symbol)
                action = to.to_s
              end

              controller ||= default_controller
              action     ||= default_action

              unless controller.is_a?(Regexp) || to_shorthand
                controller = [@scope[:module], controller].compact.join("/").presence
              end

              if controller.is_a?(String) && controller =~ %r{\A/}
                raise ArgumentError, "controller name should not start with a slash"
              end

              controller = controller.to_s unless controller.is_a?(Regexp)
              action     = action.to_s     unless action.is_a?(Regexp)

              if controller.blank? && segment_keys.exclude?("controller")
                raise ArgumentError, "missing :controller"
              end

              if action.blank? && segment_keys.exclude?("action")
                raise ArgumentError, "missing :action"
              end

              { :controller => controller, :action => action }.tap do |hash|
                hash.delete(:controller) if hash[:controller].blank?
                hash.delete(:action)     if hash[:action].blank?
              end
            end
          end

          def blocks
            if @options[:constraints].present? && !@options[:constraints].is_a?(Hash)
              block = @options[:constraints]
            else
              block = nil
            end

            ((@scope[:blocks] || []) + [ block ]).compact
          end

          def constraints
            @constraints ||= requirements.reject { |k, v| segment_keys.include?(k.to_s) || k == :controller }
          end

          def request_method_condition
            if via = @options[:via]
              via = Array(via).map { |m| m.to_s.dasherize.upcase }
              { :request_method => %r[^#{via.join('|')}$] }
            else
              { }
            end
          end

          def segment_keys
            @segment_keys ||= Rack::Mount::RegexpWithNamedGroups.new(
              Rack::Mount::Strexp.compile(@path, requirements, SEPARATORS)
            ).names
          end

          def to
            @options[:to]
          end

          def default_controller
            if @options[:controller]
              @options[:controller]
            elsif @scope[:controller]
              @scope[:controller]
            end
          end

          def default_action
            if @options[:action]
              @options[:action]
            elsif @scope[:action]
              @scope[:action]
            end
          end
      end

      # Invokes Rack::Mount::Utils.normalize path and ensure that
      # (:locale) becomes (/:locale) instead of /(:locale). Except
      # for root cases, where the latter is the correct one.
      def self.normalize_path(path)
        path = Rack::Mount::Utils.normalize_path(path)
        path.gsub!(%r{/(\(+)/?}, '\1/') unless path =~ %r{^/\(+[^/]+\)$}
        path
      end

      def self.normalize_name(name)
        normalize_path(name)[1..-1].gsub("/", "_")
      end

      module Base
        def initialize(set) #:nodoc:
          @set = set
        end

        # You can specify what Rails should route "/" to with the root method:
        #
        #   root :to => 'pages#main'
        #
        # You should put the root route at the end of <tt>config/routes.rb</tt>.
        def root(options = {})
          match '/', options.reverse_merge(:as => :root)
        end

        # When you set up a regular route, you supply a series of symbols that
        # Rails maps to parts of an incoming HTTP request.
        #
        #   match ':controller/:action/:id/:user_id'
        #
        # Two of these symbols are special: :controller maps to the name of a
        # controller in your application, and :action maps to the name of an
        # action within that controller. Anything other than :controller or
        # :action will be available to the action as part of params.
        def match(path, options=nil)
          mapping = Mapping.new(@set, @scope, path, options || {}).to_route
          @set.add_route(*mapping)
          self
        end

        # Mount a Rack-based application to be used within the application.
        #
        # mount SomeRackApp, :at => "some_route"
        #
        # Alternatively:
        #
        # mount(SomeRackApp => "some_route")
        #
        # All mounted applications come with routing helpers to access them.
        # These are named after the class specified, so for the above example
        # the helper is either +some_rack_app_path+ or +some_rack_app_url+.
        # To customize this helper's name, use the +:as+ option:
        #
        # mount(SomeRackApp => "some_route", :as => "exciting")
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

          match(path, options.merge(:to => app, :anchor => false, :format => false))
          self
        end

        def default_url_options=(options)
          @set.default_url_options = options
        end
        alias_method :default_url_options, :default_url_options=
      end

      module HttpHelpers
        # Define a route that only recognizes HTTP GET.
        # For supported arguments, see +match+.
        #
        # Example:
        #
        # get 'bacon', :to => 'food#bacon'
        def get(*args, &block)
          map_method(:get, *args, &block)
        end

        # Define a route that only recognizes HTTP POST.
        # For supported arguments, see +match+.
        #
        # Example:
        #
        # post 'bacon', :to => 'food#bacon'
        def post(*args, &block)
          map_method(:post, *args, &block)
        end

        # Define a route that only recognizes HTTP PUT.
        # For supported arguments, see +match+.
        #
        # Example:
        #
        # put 'bacon', :to => 'food#bacon'
        def put(*args, &block)
          map_method(:put, *args, &block)
        end

        # Define a route that only recognizes HTTP PUT.
        # For supported arguments, see +match+.
        #
        # Example:
        #
        # delete 'broccoli', :to => 'food#broccoli'
        def delete(*args, &block)
          map_method(:delete, *args, &block)
        end

        # Redirect any path to another path:
        #
        #   match "/stories" => redirect("/posts")
        def redirect(*args, &block)
          options = args.last.is_a?(Hash) ? args.pop : {}

          path      = args.shift || block
          path_proc = path.is_a?(Proc) ? path : proc { |params| path % params }
          status    = options[:status] || 301

          lambda do |env|
            req = Request.new(env)

            params = [req.symbolized_path_parameters]
            params << req if path_proc.arity > 1

            uri = URI.parse(path_proc.call(*params))
            uri.scheme ||= req.scheme
            uri.host   ||= req.host
            uri.port   ||= req.port unless req.standard_port?

            body = %(<html><body>You are being <a href="#{ERB::Util.h(uri.to_s)}">redirected</a>.</body></html>)

            headers = {
              'Location' => uri.to_s,
              'Content-Type' => 'text/html',
              'Content-Length' => body.length.to_s
            }

            [ status, headers, [body] ]
          end
        end

        private
          def map_method(method, *args, &block)
            options = args.extract_options!
            options[:via] = method
            args.push(options)
            match(*args, &block)
            self
          end
      end

      # You may wish to organize groups of controllers under a namespace.
      # Most commonly, you might group a number of administrative controllers
      # under an +admin+ namespace. You would place these controllers under
      # the app/controllers/admin directory, and you can group them together
      # in your router:
      #
      #   namespace "admin" do
      #     resources :posts, :comments
      #   end
      # 
      # This will create a number of routes for each of the posts and comments
      # controller. For Admin::PostsController, Rails will create:
      # 
      #   GET	    /admin/photos
      #   GET	    /admin/photos/new
      #   POST	  /admin/photos
      #   GET	    /admin/photos/1
      #   GET	    /admin/photos/1/edit
      #   PUT	    /admin/photos/1
      #   DELETE  /admin/photos/1
      # 
      # If you want to route /photos (without the prefix /admin) to
      # Admin::PostsController, you could use
      # 
      #   scope :module => "admin" do
      #     resources :posts, :comments
      #   end
      #
      # or, for a single case
      # 
      #   resources :posts, :module => "admin"
      # 
      # If you want to route /admin/photos to PostsController
      # (without the Admin:: module prefix), you could use
      # 
      #   scope "/admin" do
      #     resources :posts, :comments
      #   end
      #
      # or, for a single case
      # 
      #   resources :posts, :path => "/admin"
      #
      # In each of these cases, the named routes remain the same as if you did
      # not use scope. In the last case, the following paths map to
      # PostsController:
      # 
      #   GET	    /admin/photos
      #   GET	    /admin/photos/new
      #   POST	  /admin/photos
      #   GET	    /admin/photos/1
      #   GET	    /admin/photos/1/edit
      #   PUT	    /admin/photos/1
      #   DELETE  /admin/photos/1
      module Scoping
        def initialize(*args) #:nodoc:
          @scope = {}
          super
        end

        # Used to route <tt>/photos</tt> (without the prefix <tt>/admin</tt>)
        # to Admin::PostsController:
        # === Supported options
        # [:module]
        #   If you want to route /posts (without the prefix /admin) to
        #   Admin::PostsController, you could use
        #
        #     scope :module => "admin" do
        #       resources :posts
        #     end
        #
        # [:path]
        #   If you want to prefix the route, you could use
        #
        #     scope :path => "/admin" do
        #       resources :posts
        #     end
        #
        #   This will prefix all of the +posts+ resource's requests with '/admin'
        #
        # [:as]
        #  Prefixes the routing helpers in this scope with the specified label.
        #
        #    scope :as => "sekret" do
        #      resources :posts
        #    end
        #
        # Helpers such as +posts_path+ will now be +sekret_posts_path+
        #
        # [:shallow_path]
        #
        #   Prefixes nested shallow routes with the specified path.
        #
        #   scope :shallow_path => "sekret" do
        #     resources :posts do
        #       resources :comments, :shallow => true
        #     end
        #
        #   The +comments+ resource here will have the following routes generated for it:
        #
        #     post_comments    GET    /sekret/posts/:post_id/comments(.:format)
        #     post_comments    POST   /sekret/posts/:post_id/comments(.:format)
        #     new_post_comment GET    /sekret/posts/:post_id/comments/new(.:format)
        #     edit_comment     GET    /sekret/comments/:id/edit(.:format)
        #     comment          GET    /sekret/comments/:id(.:format)
        #     comment          PUT    /sekret/comments/:id(.:format)
        #     comment          DELETE /sekret/comments/:id(.:format)
        def scope(*args)
          options = args.extract_options!
          options = options.dup

          if name_prefix = options.delete(:name_prefix)
            options[:as] ||= name_prefix
            ActiveSupport::Deprecation.warn ":name_prefix was deprecated in the new router syntax. Use :as instead.", caller
          end

          options[:path] = args.first if args.first.is_a?(String)
          recover = {}

          options[:constraints] ||= {}
          unless options[:constraints].is_a?(Hash)
            block, options[:constraints] = options[:constraints], {}
          end

          scope_options.each do |option|
            if value = options.delete(option)
              recover[option] = @scope[option]
              @scope[option]  = send("merge_#{option}_scope", @scope[option], value)
            end
          end

          recover[:block] = @scope[:blocks]
          @scope[:blocks] = merge_blocks_scope(@scope[:blocks], block)

          recover[:options] = @scope[:options]
          @scope[:options]  = merge_options_scope(@scope[:options], options)

          yield
          self
        ensure
          scope_options.each do |option|
            @scope[option] = recover[option] if recover.has_key?(option)
          end

          @scope[:options] = recover[:options]
          @scope[:blocks]  = recover[:block]
        end

        # Scopes routes to a specific controller
        #
        # Example:
        #   controller "food" do
        #     match "bacon", :action => "bacon"
        #   end
        def controller(controller, options={})
          options[:controller] = controller
          scope(options) { yield }
        end

        # Scopes routes to a specific namespace. For example:
        #
        #   namespace :admin do
        #     resources :posts
        #   end
        #
        # This generates the following routes:
        #
        #     admin_posts GET    /admin/posts(.:format)          {:action=>"index", :controller=>"admin/posts"}
        #     admin_posts POST   /admin/posts(.:format)          {:action=>"create", :controller=>"admin/posts"}
        #  new_admin_post GET    /admin/posts/new(.:format)      {:action=>"new", :controller=>"admin/posts"}
        # edit_admin_post GET    /admin/posts/:id/edit(.:format) {:action=>"edit", :controller=>"admin/posts"}
        #      admin_post GET    /admin/posts/:id(.:format)      {:action=>"show", :controller=>"admin/posts"}
        #      admin_post PUT    /admin/posts/:id(.:format)      {:action=>"update", :controller=>"admin/posts"}
        #      admin_post DELETE /admin/posts/:id(.:format)      {:action=>"destroy", :controller=>"admin/posts"}
        # === Supported options
        #
        # The +:path+, +:as+, +:module+, +:shallow_path+ and +:shallow_prefix+ all default to the name of the namespace.
        #
        # [:path]
        #   The path prefix for the routes.
        #
        #   namespace :admin, :path => "sekret" do
        #     resources :posts
        #   end
        #
        #   All routes for the above +resources+ will be accessible through +/sekret/posts+, rather than +/admin/posts+
        #
        # [:module]
        #   The namespace for the controllers.
        #
        #   namespace :admin, :module => "sekret" do
        #     resources :posts
        #   end
        #
        #   The +PostsController+ here should go in the +Sekret+ namespace and so it should be defined like this:
        #
        #   class Sekret::PostsController < ApplicationController
        #     # code go here
        #   end
        #
        # [:as]
        #   Changes the name used in routing helpers for this namespace.
        #
        #     namespace :admin, :as => "sekret" do
        #       resources :posts
        #     end
        #
        # Routing helpers such as +admin_posts_path+ will now be +sekret_posts_path+.
        #
        # [:shallow_path]
        #   See the +scope+ method.
        def namespace(path, options = {})
          path = path.to_s
          options = { :path => path, :as => path, :module => path,
                      :shallow_path => path, :shallow_prefix => path }.merge!(options)
          scope(options) { yield }
        end
        
        # === Parameter Restriction
        # Allows you to constrain the nested routes based on a set of rules.
        # For instance, in order to change the routes to allow for a dot character in the +id+ parameter:
        #
        #   constraints(:id => /\d+\.\d+) do
        #     resources :posts
        #   end
        #
        # Now routes such as +/posts/1+ will no longer be valid, but +/posts/1.1+ will be.
        # The +id+ parameter must match the constraint passed in for this example.
        # 
        # You may use this to also resrict other parameters:
        #
        #   resources :posts do
        #     constraints(:post_id => /\d+\.\d+) do
        #       resources :comments
        #     end
        #
        # === Restricting based on IP
        #
        # Routes can also be constrained to an IP or a certain range of IP addresses:
        #
        #   constraints(:ip => /192.168.\d+.\d+/) do
        #     resources :posts
        #   end
        #
        # Any user connecting from the 192.168.* range will be able to see this resource,
        # where as any user connecting outside of this range will be told there is no such route.
        #
        # === Dynamic request matching
        #
        # Requests to routes can be constrained based on specific critera:
        #
        #    constraints(lambda { |req| req.env["HTTP_USER_AGENT"] =~ /iPhone/ }) do
        #      resources :iphones
        #    end
        #
        # You are able to move this logic out into a class if it is too complex for routes.
        # This class must have a +matches?+ method defined on it which either returns +true+
        # if the user should be given access to that route, or +false+ if the user should not.
        #
        #    class Iphone
        #      def self.matches(request)
        #        request.env["HTTP_USER_AGENT"] =~ /iPhone/
        #      end
        #    end
        #
        # An expected place for this code would be +lib/constraints+.
        #
        # This class is then used like this:
        #
        #    constraints(Iphone) do
        #      resources :iphones
        #    end
        def constraints(constraints = {})
          scope(:constraints => constraints) { yield }
        end

        # Allows you to set default parameters for a route, such as this:
        # defaults :id => 'home' do
        #   match 'scoped_pages/(:id)', :to => 'pages#show'
        # end
        # Using this, the +:id+ parameter here will default to 'home'.
        def defaults(defaults = {})
          scope(:defaults => defaults) { yield }
        end

        private
          def scope_options
            @scope_options ||= private_methods.grep(/^merge_(.+)_scope$/) { $1.to_sym }
          end

          def merge_path_scope(parent, child)
            Mapper.normalize_path("#{parent}/#{child}")
          end

          def merge_shallow_path_scope(parent, child)
            Mapper.normalize_path("#{parent}/#{child}")
          end

          def merge_as_scope(parent, child)
            parent ? "#{parent}_#{child}" : child
          end

          def merge_shallow_prefix_scope(parent, child)
            parent ? "#{parent}_#{child}" : child
          end

          def merge_module_scope(parent, child)
            parent ? "#{parent}/#{child}" : child
          end

          def merge_controller_scope(parent, child)
            child
          end

          def merge_path_names_scope(parent, child)
            merge_options_scope(parent, child)
          end

          def merge_constraints_scope(parent, child)
            merge_options_scope(parent, child)
          end

          def merge_defaults_scope(parent, child)
            merge_options_scope(parent, child)
          end

          def merge_blocks_scope(parent, child)
            merged = parent ? parent.dup : []
            merged << child if child
            merged
          end

          def merge_options_scope(parent, child)
            (parent || {}).except(*override_keys(child)).merge(child)
          end

          def merge_shallow_scope(parent, child)
            child ? true : false
          end

          def override_keys(child)
            child.key?(:only) || child.key?(:except) ? [:only, :except] : []
          end
      end

      # Resource routing allows you to quickly declare all of the common routes
      # for a given resourceful controller. Instead of declaring separate routes
      # for your +index+, +show+, +new+, +edit+, +create+, +update+ and +destroy+
      # actions, a resourceful route declares them in a single line of code:
      #
      #  resources :photos
      #
      # Sometimes, you have a resource that clients always look up without
      # referencing an ID. A common example, /profile always shows the profile of
      # the currently logged in user. In this case, you can use a singular resource
      # to map /profile (rather than /profile/:id) to the show action.
      #
      #  resource :profile
      #
      # It's common to have resources that are logically children of other
      # resources:
      #
      #   resources :magazines do
      #     resources :ads
      #   end
      #
      # You may wish to organize groups of controllers under a namespace. Most
      # commonly, you might group a number of administrative controllers under
      # an +admin+ namespace. You would place these controllers under the
      # app/controllers/admin directory, and you can group them together in your
      # router:
      #
      #   namespace "admin" do
      #     resources :posts, :comments
      #   end
      #
      module Resources
        # CANONICAL_ACTIONS holds all actions that does not need a prefix or
        # a path appended since they fit properly in their scope level.
        VALID_ON_OPTIONS  = [:new, :collection, :member]
        RESOURCE_OPTIONS  = [:as, :controller, :path, :only, :except]
        CANONICAL_ACTIONS = %w(index create new show update destroy)

        class Resource #:nodoc:
          DEFAULT_ACTIONS = [:index, :create, :new, :show, :update, :destroy, :edit]

          attr_reader :controller, :path, :options

          def initialize(entities, options = {})
            @name       = entities.to_s
            @path       = (options.delete(:path) || @name).to_s
            @controller = (options.delete(:controller) || @name).to_s
            @as         = options.delete(:as)
            @options    = options
          end

          def default_actions
            self.class::DEFAULT_ACTIONS
          end

          def actions
            if only = @options[:only]
              Array(only).map(&:to_sym)
            elsif except = @options[:except]
              default_actions - Array(except).map(&:to_sym)
            else
              default_actions
            end
          end

          def name
            @as || @name
          end

          def plural
            @plural ||= name.to_s
          end

          def singular
            @singular ||= name.to_s.singularize
          end

          alias :member_name :singular

          # Checks for uncountable plurals, and appends "_index" if they're.
          def collection_name
            singular == plural ? "#{plural}_index" : plural
          end

          def resource_scope
            { :controller => controller }
          end

          alias :collection_scope :path

          def member_scope
            "#{path}/:id"
          end

          def new_scope(new_path)
            "#{path}/#{new_path}"
          end

          def nested_scope
            "#{path}/:#{singular}_id"
          end

        end

        class SingletonResource < Resource #:nodoc:
          DEFAULT_ACTIONS = [:show, :create, :update, :destroy, :new, :edit]

          def initialize(entities, options)
            @name       = entities.to_s
            @path       = (options.delete(:path) || @name).to_s
            @controller = (options.delete(:controller) || plural).to_s
            @as         = options.delete(:as)
            @options    = options
          end

          def plural
            @plural ||= name.to_s.pluralize
          end

          def singular
            @singular ||= name.to_s
          end

          alias :member_name :singular
          alias :collection_name :singular

          alias :member_scope :path
          alias :nested_scope :path
        end

        def initialize(*args) #:nodoc:
          super
          @scope[:path_names] = @set.resources_path_names
        end

        def resources_path_names(options)
          @scope[:path_names].merge!(options)
        end

        # Sometimes, you have a resource that clients always look up without
        # referencing an ID. A common example, /profile always shows the
        # profile of the currently logged in user. In this case, you can use
        # a singular resource to map /profile (rather than /profile/:id) to
        # the show action:
        #
        #   resource :geocoder
        #
        # creates six different routes in your application, all mapping to
        # the GeoCoders controller (note that the controller is named after
        # the plural):
        #
        #   GET     /geocoder/new
        #   POST    /geocoder
        #   GET     /geocoder
        #   GET     /geocoder/edit
        #   PUT     /geocoder
        #   DELETE  /geocoder
        def resource(*resources, &block)
          options = resources.extract_options!

          if apply_common_behavior_for(:resource, resources, options, &block)
            return self
          end

          resource_scope(SingletonResource.new(resources.pop, options)) do
            yield if block_given?

            collection do
              post :create
            end if parent_resource.actions.include?(:create)

            new do
              get :new
            end if parent_resource.actions.include?(:new)

            member do
              get    :edit if parent_resource.actions.include?(:edit)
              get    :show if parent_resource.actions.include?(:show)
              put    :update if parent_resource.actions.include?(:update)
              delete :destroy if parent_resource.actions.include?(:destroy)
            end
          end

          self
        end

        # In Rails, a resourceful route provides a mapping between HTTP verbs
        # and URLs and controller actions. By convention, each action also maps
        # to particular CRUD operations in a database. A single entry in the
        # routing file, such as
        #
        #   resources :photos
        #
        # creates seven different routes in your application, all mapping to
        # the Photos controller:
        #
        #   GET     /photos/new
        #   POST    /photos
        #   GET     /photos/:id
        #   GET     /photos/:id/edit
        #   PUT     /photos/:id
        #   DELETE  /photos/:id
        # === Supported options
        # [:path_names]
        #   Allows you to change the paths of the seven default actions.
        #   Paths not specified are not changed.
        #
        #     resources :posts, :path_names => { :new => "brand_new" }
        #
        #   The above example will now change /posts/new to /posts/brand_new
        def resources(*resources, &block)
          options = resources.extract_options!

          if apply_common_behavior_for(:resources, resources, options, &block)
            return self
          end

          resource_scope(Resource.new(resources.pop, options)) do
            yield if block_given?

            collection do
              get  :index if parent_resource.actions.include?(:index)
              post :create if parent_resource.actions.include?(:create)
            end

            new do
              get :new
            end if parent_resource.actions.include?(:new)

            member do
              get    :edit if parent_resource.actions.include?(:edit)
              get    :show if parent_resource.actions.include?(:show)
              put    :update if parent_resource.actions.include?(:update)
              delete :destroy if parent_resource.actions.include?(:destroy)
            end
          end

          self
        end

        # To add a route to the collection:
        #
        #   resources :photos do
        #     collection do
        #       get 'search'
        #     end
        #   end
        #
        # This will enable Rails to recognize paths such as <tt>/photos/search</tt>
        # with GET, and route to the search action of PhotosController. It will also
        # create the <tt>search_photos_url</tt> and <tt>search_photos_path</tt>
        # route helpers.
        def collection
          unless resource_scope?
            raise ArgumentError, "can't use collection outside resource(s) scope"
          end

          with_scope_level(:collection) do
            scope(parent_resource.collection_scope) do
              yield
            end
          end
        end

        # To add a member route, add a member block into the resource block:
        #
        #   resources :photos do
        #     member do
        #       get 'preview'
        #     end
        #   end
        #
        # This will recognize <tt>/photos/1/preview</tt> with GET, and route to the
        # preview action of PhotosController. It will also create the
        # <tt>preview_photo_url</tt> and <tt>preview_photo_path</tt> helpers.
        def member
          unless resource_scope?
            raise ArgumentError, "can't use member outside resource(s) scope"
          end

          with_scope_level(:member) do
            scope(parent_resource.member_scope) do
              yield
            end
          end
        end

        def new
          unless resource_scope?
            raise ArgumentError, "can't use new outside resource(s) scope"
          end

          with_scope_level(:new) do
            scope(parent_resource.new_scope(action_path(:new))) do
              yield
            end
          end
        end

        def nested
          unless resource_scope?
            raise ArgumentError, "can't use nested outside resource(s) scope"
          end

          with_scope_level(:nested) do
            if shallow?
              with_exclusive_scope do
                if @scope[:shallow_path].blank?
                  scope(parent_resource.nested_scope, nested_options) { yield }
                else
                  scope(@scope[:shallow_path], :as => @scope[:shallow_prefix]) do
                    scope(parent_resource.nested_scope, nested_options) { yield }
                  end
                end
              end
            else
              scope(parent_resource.nested_scope, nested_options) { yield }
            end
          end
        end

        def namespace(path, options = {})
          if resource_scope?
            nested { super }
          else
            super
          end
        end

        def shallow
          scope(:shallow => true) do
            yield
          end
        end

        def shallow?
          parent_resource.instance_of?(Resource) && @scope[:shallow]
        end

        def match(*args)
          options = args.extract_options!.dup
          options[:anchor] = true unless options.key?(:anchor)

          if args.length > 1
            args.each { |path| match(path, options.dup) }
            return self
          end

          on = options.delete(:on)
          if VALID_ON_OPTIONS.include?(on)
            args.push(options)
            return send(on){ match(*args) }
          elsif on
            raise ArgumentError, "Unknown scope #{on.inspect} given to :on"
          end

          if @scope[:scope_level] == :resources
            args.push(options)
            return nested { match(*args) }
          elsif @scope[:scope_level] == :resource
            args.push(options)
            return member { match(*args) }
          end

          action = args.first
          path = path_for_action(action, options.delete(:path))

          if action.to_s =~ /^[\w\/]+$/
            options[:action] ||= action unless action.to_s.include?("/")
          else
            action = nil
          end

          if options.key?(:as) && !options[:as]
            options.delete(:as)
          else
            options[:as] = name_for_action(options[:as], action)
          end

          super(path, options)
        end

        def root(options={})
          if @scope[:scope_level] == :resources
            with_scope_level(:root) do
              scope(parent_resource.path) do
                super(options)
              end
            end
          else
            super(options)
          end
        end

        protected

          def parent_resource #:nodoc:
            @scope[:scope_level_resource]
          end

          def apply_common_behavior_for(method, resources, options, &block)
            if resources.length > 1
              resources.each { |r| send(method, r, options, &block) }
              return true
            end

            if resource_scope?
              nested { send(method, resources.pop, options, &block) }
              return true
            end

            options.keys.each do |k|
              (options[:constraints] ||= {})[k] = options.delete(k) if options[k].is_a?(Regexp)
            end

            scope_options = options.slice!(*RESOURCE_OPTIONS)
            unless scope_options.empty?
              scope(scope_options) do
                send(method, resources.pop, options, &block)
              end
              return true
            end

            unless action_options?(options)
              options.merge!(scope_action_options) if scope_action_options?
            end

            false
          end

          def action_options?(options)
            options[:only] || options[:except]
          end

          def scope_action_options?
            @scope[:options].is_a?(Hash) && (@scope[:options][:only] || @scope[:options][:except])
          end

          def scope_action_options
            @scope[:options].slice(:only, :except)
          end

          def resource_scope?
            [:resource, :resources].include?(@scope[:scope_level])
          end

          def resource_method_scope?
            [:collection, :member, :new].include?(@scope[:scope_level])
          end

          def with_exclusive_scope
            begin
              old_name_prefix, old_path = @scope[:as], @scope[:path]
              @scope[:as], @scope[:path] = nil, nil

              with_scope_level(:exclusive) do
                yield
              end
            ensure
              @scope[:as], @scope[:path] = old_name_prefix, old_path
            end
          end

          def with_scope_level(kind, resource = parent_resource)
            old, @scope[:scope_level] = @scope[:scope_level], kind
            old_resource, @scope[:scope_level_resource] = @scope[:scope_level_resource], resource
            yield
          ensure
            @scope[:scope_level] = old
            @scope[:scope_level_resource] = old_resource
          end

          def resource_scope(resource)
            with_scope_level(resource.is_a?(SingletonResource) ? :resource : :resources, resource) do
              scope(parent_resource.resource_scope) do
                yield
              end
            end
          end

          def nested_options
            {}.tap do |options|
              options[:as] = parent_resource.member_name
              options[:constraints] = { "#{parent_resource.singular}_id".to_sym => id_constraint } if id_constraint?
            end
          end

          def id_constraint?
            @scope[:constraints] && @scope[:constraints][:id].is_a?(Regexp)
          end

          def id_constraint
            @scope[:constraints][:id]
          end

          def canonical_action?(action, flag)
            flag && resource_method_scope? && CANONICAL_ACTIONS.include?(action.to_s)
          end

          def shallow_scoping?
            shallow? && @scope[:scope_level] == :member
          end

          def path_for_action(action, path)
            prefix = shallow_scoping? ?
              "#{@scope[:shallow_path]}/#{parent_resource.path}/:id" : @scope[:path]

            path = if canonical_action?(action, path.blank?)
              prefix.to_s
            else
              "#{prefix}/#{action_path(action, path)}"
            end
          end

          def action_path(name, path = nil)
            path || @scope[:path_names][name.to_sym] || name.to_s
          end

          def prefix_name_for_action(as, action)
            if as
              as.to_s
            elsif !canonical_action?(action, @scope[:scope_level])
              action.to_s
            end
          end

          def name_for_action(as, action)
            prefix = prefix_name_for_action(as, action)
            prefix = Mapper.normalize_name(prefix) if prefix
            name_prefix = @scope[:as]

            if parent_resource
              collection_name = parent_resource.collection_name
              member_name = parent_resource.member_name
            end

            name = case @scope[:scope_level]
            when :nested
              [member_name, prefix]
            when :collection
              [prefix, name_prefix, collection_name]
            when :new
              [prefix, :new, name_prefix, member_name]
            when :member
              [prefix, shallow_scoping? ? @scope[:shallow_prefix] : name_prefix, member_name]
            when :root
              [name_prefix, collection_name, prefix]
            else
              [name_prefix, member_name, prefix]
            end

            candidate = name.select(&:present?).join("_").presence
            candidate unless as.nil? && @set.routes.find { |r| r.name == candidate }
          end
      end

      module Shorthand
        def match(*args)
          if args.size == 1 && args.last.is_a?(Hash)
            options  = args.pop
            path, to = options.find { |name, value| name.is_a?(String) }
            options.merge!(:to => to).delete(path)
            super(path, options)
          else
            super
          end
        end
      end

      include Base
      include HttpHelpers
      include Scoping
      include Resources
      include Shorthand
    end
  end
end
