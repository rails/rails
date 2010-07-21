require 'active_support/core_ext/object/to_param'
require 'active_support/core_ext/regexp'

module ActionDispatch
  # = Routing
  #
  # The routing module provides URL rewriting in native Ruby. It's a way to
  # redirect incoming requests to controllers and actions. This replaces
  # mod_rewrite rules. Best of all, Rails' Routing works with any web server.
  # Routes are defined in <tt>config/routes.rb</tt>.
  #
  # Consider the following route, which you will find commented out at the
  # bottom of your generated <tt>config/routes.rb</tt>:
  #
  #   match ':controller(/:action(/:id(.:format)))'
  #
  # This route states that it expects requests to consist of a
  # <tt>:controller</tt> followed optionally by an <tt>:action</tt> that in 
  # turn is followed optionally by an <tt>:id</tt>, which in turn is followed
  # optionally by a <tt>:format</tt>
  #
  # Suppose you get an incoming request for <tt>/blog/edit/22</tt>, you'll end
  # up with:
  #
  #   params = { :controller => 'blog',
  #              :action     => 'edit',
  #              :id         => '22'
  #           }
  #
  # Think of creating routes as drawing a map for your requests. The map tells
  # them where to go based on some predefined pattern:
  #
  #   AppName::Application.routes.draw do
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
  # == Named routes
  #
  # Routes can be named by passing an <tt>:as</tt> option,
  # allowing for easy reference within your source as +name_of_route_url+
  # for the full URL and +name_of_route_path+ for the URI path.
  #
  # Example:
  #
  #   # In routes.rb
  #   match '/login' => 'accounts#login', :as => 'login'
  #
  #   # With render, redirect_to, tests, etc.
  #   redirect_to login_url
  #
  # Arguments can be passed as well.
  #
  #   redirect_to show_item_path(:id => 25)
  #
  # Use <tt>root</tt> as a shorthand to name a route for the root path "/".
  #
  #   # In routes.rb
  #   root :to => 'blogs#index'
  #
  #   # would recognize http://www.example.com/ as
  #   params = { :controller => 'blogs', :action => 'index' }
  #
  #   # and provide these named routes
  #   root_url   # => 'http://www.example.com/'
  #   root_path  # => '/'
  #
  # Note: when using +controller+, the route is simply named after the
  # method you call on the block parameter rather than map.
  #
  #   # In routes.rb
  #   controller :blog do
  #     match 'blog/show'     => :list
  #     match 'blog/delete'   => :delete
  #     match 'blog/edit/:id' => :edit
  #   end
  #
  #   # provides named routes for show, delete, and edit
  #   link_to @article.title, show_path(:id => @article.id)
  #
  # == Pretty URLs
  #
  # Routes can generate pretty URLs. For example:
  #
  #   match '/articles/:year/:month/:day' => 'articles#find_by_id', :constraints => {
  #     :year       => /\d{4}/,
  #     :month      => /\d{1,2}/,
  #     :day        => /\d{1,2}/
  #   }
  #
  # Using the route above, the URL "http://localhost:3000/articles/2005/11/06"
  # maps to
  #
  #   params = {:year => '2005', :month => '11', :day => '06'}
  #
  # == Regular Expressions and parameters
  # You can specify a regular expression to define a format for a parameter.
  #
  #   controller 'geocode' do
  #     match 'geocode/:postalcode' => :show, :constraints => {
  #       :postalcode => /\d{5}(-\d{4})?/
  #     }
  #
  # Constraints can include the 'ignorecase' and 'extended syntax' regular
  # expression modifiers:
  #
  #   controller 'geocode' do
  #     match 'geocode/:postalcode' => :show, :constraints => {
  #       :postalcode => /hx\d\d\s\d[a-z]{2}/i
  #     }
  #   end
  #
  #   controller 'geocode' do
  #     match 'geocode/:postalcode' => :show, :constraints => {
  #       :postalcode => /# Postcode format
  #          \d{5} #Prefix
  #          (-\d{4})? #Suffix
  #          /x
  #     }
  #   end
  #
  # Using the multiline match modifier will raise an ArgumentError.
  # Encoding regular expression modifiers are silently ignored. The
  # match will always use the default encoding or ASCII.
  #
  # == HTTP Methods
  #
  # Using the <tt>:via</tt> option when specifying a route allows you to restrict it to a specific HTTP method.
  # Possible values are <tt>:post</tt>, <tt>:get</tt>, <tt>:put</tt>, <tt>:delete</tt> and <tt>:any</tt>. 
  # If your route needs to respond to more than one method you can use an array, e.g. <tt>[ :get, :post ]</tt>. 
  # The default value is <tt>:any</tt> which means that the route will respond to any of the HTTP methods.
  #
  # Examples:
  #
  #   match 'post/:id' => 'posts#show', :via => :get
  #   match 'post/:id' => "posts#create_comment', :via => :post
  #
  # Now, if you POST to <tt>/posts/:id</tt>, it will route to the <tt>create_comment</tt> action. A GET on the same
  # URL will route to the <tt>show</tt> action. 
  #
  # === HTTP helper methods
  #
  # An alternative method of specifying which HTTP method a route should respond to is to use the helper
  # methods <tt>get</tt>, <tt>post</tt>, <tt>put</tt> and <tt>delete</tt>.
  #
  # Examples:
  #
  #   get 'post/:id' => 'posts#show'
  #   post 'post/:id' => "posts#create_comment'
  #
  # This syntax is less verbose and the intention is more apparent to someone else reading your code,
  # however if your route needs to respond to more than one HTTP method (or all methods) then using the
  # <tt>:via</tt> option on <tt>match</tt> is preferable.
  #
  # == Reloading routes
  #
  # You can reload routes if you feel you must:
  #
  #   Rails.application.reload_routes!
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
    autoload :DeprecatedMapper, 'action_dispatch/routing/deprecated_mapper'
    autoload :Mapper, 'action_dispatch/routing/mapper'
    autoload :Route, 'action_dispatch/routing/route'
    autoload :RouteSet, 'action_dispatch/routing/route_set'
    autoload :UrlFor, 'action_dispatch/routing/url_for'
    autoload :PolymorphicRoutes, 'action_dispatch/routing/polymorphic_routes'

    SEPARATORS = %w( / . ? ) #:nodoc:
    HTTP_METHODS = [:get, :head, :post, :put, :delete, :options] #:nodoc:

    # A helper module to hold URL related helpers.
    module Helpers #:nodoc:
      include PolymorphicRoutes
    end
  end
end
