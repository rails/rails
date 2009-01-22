require 'cgi'
require 'uri'
require 'action_controller/routing/optimisations'
require 'action_controller/routing/routing_ext'
require 'action_controller/routing/route'
require 'action_controller/routing/segments'
require 'action_controller/routing/builder'
require 'action_controller/routing/route_set'
require 'action_controller/routing/recognition_optimisation'

module ActionController
  # == Routing
  #
  # The routing module provides URL rewriting in native Ruby. It's a way to
  # redirect incoming requests to controllers and actions. This replaces
  # mod_rewrite rules. Best of all, Rails' Routing works with any web server.
  # Routes are defined in <tt>config/routes.rb</tt>.
  #
  # Consider the following route, installed by Rails when you generate your
  # application:
  #
  #   map.connect ':controller/:action/:id'
  #
  # This route states that it expects requests to consist of a
  # <tt>:controller</tt> followed by an <tt>:action</tt> that in turn is fed
  # some <tt>:id</tt>.
  #
  # Suppose you get an incoming request for <tt>/blog/edit/22</tt>, you'll end up
  # with:
  #
  #   params = { :controller => 'blog',
  #              :action     => 'edit',
  #              :id         => '22'
  #           }
  #
  # Think of creating routes as drawing a map for your requests. The map tells
  # them where to go based on some predefined pattern:
  #
  #   ActionController::Routing::Routes.draw do |map|
  #     Pattern 1 tells some request to go to one place
  #     Pattern 2 tell them to go to another
  #     ...
  #   end
  #
  # The following symbols are special:
  #
  #   :controller maps to your controller name
  #   :action     maps to an action with your controllers
  #
  # Other names simply map to a parameter as in the case of <tt>:id</tt>.
  #
  # == Route priority
  #
  # Not all routes are created equally. Routes have priority defined by the
  # order of appearance of the routes in the <tt>config/routes.rb</tt> file. The priority goes
  # from top to bottom. The last route in that file is at the lowest priority
  # and will be applied last. If no route matches, 404 is returned.
  #
  # Within blocks, the empty pattern is at the highest priority.
  # In practice this works out nicely:
  #
  #   ActionController::Routing::Routes.draw do |map|
  #     map.with_options :controller => 'blog' do |blog|
  #       blog.show '',  :action => 'list'
  #     end
  #     map.connect ':controller/:action/:view'
  #   end
  #
  # In this case, invoking blog controller (with an URL like '/blog/')
  # without parameters will activate the 'list' action by default.
  #
  # == Defaults routes and default parameters
  #
  # Setting a default route is straightforward in Rails - you simply append a
  # Hash at the end of your mapping to set any default parameters.
  #
  # Example:
  #
  #   ActionController::Routing:Routes.draw do |map|
  #     map.connect ':controller/:action/:id', :controller => 'blog'
  #   end
  #
  # This sets up +blog+ as the default controller if no other is specified.
  # This means visiting '/' would invoke the blog controller.
  #
  # More formally, you can include arbitrary parameters in the route, thus:
  #
  #   map.connect ':controller/:action/:id', :action => 'show', :page => 'Dashboard'
  #
  # This will pass the :page parameter to all incoming requests that match this route.
  #
  # Note: The default routes, as provided by the Rails generator, make all actions in every
  # controller accessible via GET requests. You should consider removing them or commenting
  # them out if you're using named routes and resources.
  #
  # == Named routes
  #
  # Routes can be named with the syntax <tt>map.name_of_route options</tt>,
  # allowing for easy reference within your source as +name_of_route_url+
  # for the full URL and +name_of_route_path+ for the URI path.
  #
  # Example:
  #
  #   # In routes.rb
  #   map.login 'login', :controller => 'accounts', :action => 'login'
  #
  #   # With render, redirect_to, tests, etc.
  #   redirect_to login_url
  #
  # Arguments can be passed as well.
  #
  #   redirect_to show_item_path(:id => 25)
  #
  # Use <tt>map.root</tt> as a shorthand to name a route for the root path "".
  #
  #   # In routes.rb
  #   map.root :controller => 'blogs'
  #
  #   # would recognize http://www.example.com/ as
  #   params = { :controller => 'blogs', :action => 'index' }
  #
  #   # and provide these named routes
  #   root_url   # => 'http://www.example.com/'
  #   root_path  # => ''
  #
  # You can also specify an already-defined named route in your <tt>map.root</tt> call:
  #
  #   # In routes.rb
  #   map.new_session :controller => 'sessions', :action => 'new'
  #   map.root :new_session
  #
  # Note: when using +with_options+, the route is simply named after the
  # method you call on the block parameter rather than map.
  #
  #   # In routes.rb
  #   map.with_options :controller => 'blog' do |blog|
  #     blog.show    '',            :action  => 'list'
  #     blog.delete  'delete/:id',  :action  => 'delete',
  #     blog.edit    'edit/:id',    :action  => 'edit'
  #   end
  #
  #   # provides named routes for show, delete, and edit
  #   link_to @article.title, show_path(:id => @article.id)
  #
  # == Pretty URLs
  #
  # Routes can generate pretty URLs. For example:
  #
  #   map.connect 'articles/:year/:month/:day',
  #               :controller => 'articles',
  #               :action     => 'find_by_date',
  #               :year       => /\d{4}/,
  #               :month      => /\d{1,2}/,
  #               :day        => /\d{1,2}/
  #
  # Using the route above, the URL "http://localhost:3000/articles/2005/11/06"
  # maps to
  #
  #   params = {:year => '2005', :month => '11', :day => '06'}
  #
  # == Regular Expressions and parameters
  # You can specify a regular expression to define a format for a parameter.
  #
  #   map.geocode 'geocode/:postalcode', :controller => 'geocode',
  #               :action => 'show', :postalcode => /\d{5}(-\d{4})?/
  #
  # or, more formally:
  #
  #   map.geocode 'geocode/:postalcode', :controller => 'geocode',
  #               :action => 'show', :requirements => { :postalcode => /\d{5}(-\d{4})?/ }
  #
  # Formats can include the 'ignorecase' and 'extended syntax' regular
  # expression modifiers:
  #
  #   map.geocode 'geocode/:postalcode', :controller => 'geocode',
  #               :action => 'show', :postalcode => /hx\d\d\s\d[a-z]{2}/i
  #
  #   map.geocode 'geocode/:postalcode', :controller => 'geocode',
  #               :action => 'show',:requirements => {
  #                 :postalcode => /# Postcode format
  #                                 \d{5} #Prefix
  #                                 (-\d{4})? #Suffix
  #                                 /x
  #               }
  #
  # Using the multiline match modifier will raise an ArgumentError.
  # Encoding regular expression modifiers are silently ignored. The
  # match will always use the default encoding or ASCII.
  #
  # == Route globbing
  #
  # Specifying <tt>*[string]</tt> as part of a rule like:
  #
  #   map.connect '*path' , :controller => 'blog' , :action => 'unrecognized?'
  #
  # will glob all remaining parts of the route that were not recognized earlier. 
  # The globbed values are in <tt>params[:path]</tt> as an array of path segments.
  #
  # == Route conditions
  #
  # With conditions you can define restrictions on routes. Currently the only valid condition is <tt>:method</tt>.
  #
  # * <tt>:method</tt> - Allows you to specify which method can access the route. Possible values are <tt>:post</tt>,
  #   <tt>:get</tt>, <tt>:put</tt>, <tt>:delete</tt> and <tt>:any</tt>. The default value is <tt>:any</tt>,
  #   <tt>:any</tt> means that any method can access the route.
  #
  # Example:
  #
  #   map.connect 'post/:id', :controller => 'posts', :action => 'show',
  #               :conditions => { :method => :get }
  #   map.connect 'post/:id', :controller => 'posts', :action => 'create_comment',
  #               :conditions => { :method => :post }
  #
  # Now, if you POST to <tt>/posts/:id</tt>, it will route to the <tt>create_comment</tt> action. A GET on the same
  # URL will route to the <tt>show</tt> action.
  #
  # == Reloading routes
  #
  # You can reload routes if you feel you must:
  #
  #   ActionController::Routing::Routes.reload
  #
  # This will clear all named routes and reload routes.rb if the file has been modified from
  # last load. To absolutely force reloading, use <tt>reload!</tt>.
  #
  # == Testing Routes
  #
  # The two main methods for testing your routes:
  #
  # === +assert_routing+
  #
  #   def test_movie_route_properly_splits
  #    opts = {:controller => "plugin", :action => "checkout", :id => "2"}
  #    assert_routing "plugin/checkout/2", opts
  #   end
  #
  # +assert_routing+ lets you test whether or not the route properly resolves into options.
  #
  # === +assert_recognizes+
  #
  #   def test_route_has_options
  #    opts = {:controller => "plugin", :action => "show", :id => "12"}
  #    assert_recognizes opts, "/plugins/show/12"
  #   end
  #
  # Note the subtle difference between the two: +assert_routing+ tests that
  # a URL fits options while +assert_recognizes+ tests that a URL
  # breaks into parameters properly.
  #
  # In tests you can simply pass the URL or named route to +get+ or +post+.
  #
  #   def send_to_jail
  #     get '/jail'
  #     assert_response :success
  #     assert_template "jail/front"
  #   end
  #
  #   def goes_to_login
  #     get login_url
  #     #...
  #   end
  #
  # == View a list of all your routes
  #
  # Run <tt>rake routes</tt>.
  #
  module Routing
    SEPARATORS = %w( / . ? )

    HTTP_METHODS = [:get, :head, :post, :put, :delete]

    ALLOWED_REQUIREMENTS_FOR_OPTIMISATION = [:controller, :action].to_set

    # The root paths which may contain controller files
    mattr_accessor :controller_paths
    self.controller_paths = []

    # A helper module to hold URL related helpers.
    module Helpers
      include PolymorphicRoutes
    end

    class << self
      # Expects an array of controller names as the first argument.
      # Executes the passed block with only the named controllers named available.
      # This method is used in internal Rails testing.
      def with_controllers(names)
        prior_controllers = @possible_controllers
        use_controllers! names
        yield
      ensure
        use_controllers! prior_controllers
      end

      # Returns an array of paths, cleaned of double-slashes and relative path references.
      # * "\\\" and "//"  become "\\" or "/".
      # * "/foo/bar/../config" becomes "/foo/config".
      # The returned array is sorted by length, descending.
      def normalize_paths(paths)
        # do the hokey-pokey of path normalization...
        paths = paths.collect do |path|
          path = path.
            gsub("//", "/").           # replace double / chars with a single
            gsub("\\\\", "\\").        # replace double \ chars with a single
            gsub(%r{(.)[\\/]$}, '\1')  # drop final / or \ if path ends with it

          # eliminate .. paths where possible
          re = %r{[^/\\]+[/\\]\.\.[/\\]}
          path.gsub!(re, "") while path.match(re)
          path
        end

        # start with longest path, first
        paths = paths.uniq.sort_by { |path| - path.length }
      end

      # Returns the array of controller names currently available to ActionController::Routing.
      def possible_controllers
        unless @possible_controllers
          @possible_controllers = []

          paths = controller_paths.select { |path| File.directory?(path) && path != "." }

          seen_paths = Hash.new {|h, k| h[k] = true; false}
          normalize_paths(paths).each do |load_path|
            Dir["#{load_path}/**/*_controller.rb"].collect do |path|
              next if seen_paths[path.gsub(%r{^\.[/\\]}, "")]

              controller_name = path[(load_path.length + 1)..-1]

              controller_name.gsub!(/_controller\.rb\Z/, '')
              @possible_controllers << controller_name
            end
          end

          # remove duplicates
          @possible_controllers.uniq!
        end
        @possible_controllers
      end

      # Replaces the internal list of controllers available to ActionController::Routing with the passed argument.
      #   ActionController::Routing.use_controllers!([ "posts", "comments", "admin/comments" ])
      def use_controllers!(controller_names)
        @possible_controllers = controller_names
      end

      # Returns a controller path for a new +controller+ based on a +previous+ controller path.
      # Handles 4 scenarios:
      #
      # * stay in the previous controller:
      #     controller_relative_to( nil, "groups/discussion" ) # => "groups/discussion"
      #
      # * stay in the previous namespace:
      #     controller_relative_to( "posts", "groups/discussion" ) # => "groups/posts"
      #
      # * forced move to the root namespace:
      #     controller_relative_to( "/posts", "groups/discussion" ) # => "posts"
      #
      # * previous namespace is root:
      #     controller_relative_to( "posts", "anything_with_no_slashes" ) # =>"posts"
      #
      def controller_relative_to(controller, previous)
        if controller.nil?           then previous
        elsif controller[0] == ?/    then controller[1..-1]
        elsif %r{^(.*)/} =~ previous then "#{$1}/#{controller}"
        else controller
        end
      end
    end

    Routes = RouteSet.new

    ActiveSupport::Inflector.module_eval do
      # Ensures that routes are reloaded when Rails inflections are updated.
      def inflections_with_route_reloading(&block)
        returning(inflections_without_route_reloading(&block)) {
          ActionController::Routing::Routes.reload! if block_given?
        }
      end

      alias_method_chain :inflections, :route_reloading
    end
  end
end
