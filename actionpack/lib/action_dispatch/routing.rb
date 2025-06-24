# frozen_string_literal: true

# :markup: markdown

module ActionDispatch
  # The routing module provides URL rewriting in native Ruby. It's a way to
  # redirect incoming requests to controllers and actions. This replaces
  # mod_rewrite rules. Best of all, Rails' Routing works with any web server.
  # Routes are defined in `config/routes.rb`.
  #
  # Think of creating routes as drawing a map for your requests. The map tells
  # them where to go based on some predefined pattern:
  #
  #     Rails.application.routes.draw do
  #       Pattern 1 tells some request to go to one place
  #       Pattern 2 tell them to go to another
  #       ...
  #     end
  #
  # The following symbols are special:
  #
  #     :controller maps to your controller name
  #     :action     maps to an action with your controllers
  #
  # Other names simply map to a parameter as in the case of `:id`.
  #
  # ## Resources
  #
  # Resource routing allows you to quickly declare all of the common routes for a
  # given resourceful controller. Instead of declaring separate routes for your
  # `index`, `show`, `new`, `edit`, `create`, `update`, and `destroy` actions, a
  # resourceful route declares them in a single line of code:
  #
  #     resources :photos
  #
  # Sometimes, you have a resource that clients always look up without referencing
  # an ID. A common example, /profile always shows the profile of the currently
  # logged in user. In this case, you can use a singular resource to map /profile
  # (rather than /profile/:id) to the show action.
  #
  #     resource :profile
  #
  # It's common to have resources that are logically children of other resources:
  #
  #     resources :magazines do
  #       resources :ads
  #     end
  #
  # You may wish to organize groups of controllers under a namespace. Most
  # commonly, you might group a number of administrative controllers under an
  # `admin` namespace. You would place these controllers under the
  # `app/controllers/admin` directory, and you can group them together in your
  # router:
  #
  #     namespace "admin" do
  #       resources :posts, :comments
  #     end
  #
  # Alternatively, you can add prefixes to your path without using a separate
  # directory by using `scope`. `scope` takes additional options which apply to
  # all enclosed routes.
  #
  #     scope path: "/cpanel", as: 'admin' do
  #       resources :posts, :comments
  #     end
  #
  # For more, see Routing::Mapper::Resources#resources,
  # Routing::Mapper::Scoping#namespace, and Routing::Mapper::Scoping#scope.
  #
  # ## Non-resourceful routes
  #
  # For routes that don't fit the `resources` mold, you can use the HTTP helper
  # methods `get`, `post`, `patch`, `put` and `delete`.
  #
  #     get 'post/:id', to: 'posts#show'
  #     post 'post/:id', to: 'posts#create_comment'
  #
  # Now, if you POST to `/posts/:id`, it will route to the `create_comment`
  # action. A GET on the same URL will route to the `show` action.
  #
  # If your route needs to respond to more than one HTTP method (or all methods)
  # then using the `:via` option on `match` is preferable.
  #
  #     match 'post/:id', to: 'posts#show', via: [:get, :post]
  #
  # ## Named routes
  #
  # Routes can be named by passing an `:as` option, allowing for easy reference
  # within your source as `name_of_route_url` for the full URL and
  # `name_of_route_path` for the URI path.
  #
  # Example:
  #
  #     # In config/routes.rb
  #     get '/login', to: 'accounts#login', as: 'login'
  #
  #     # With render, redirect_to, tests, etc.
  #     redirect_to login_url
  #
  # Arguments can be passed as well.
  #
  #     redirect_to show_item_path(id: 25)
  #
  # Use `root` as a shorthand to name a route for the root path "/".
  #
  #     # In config/routes.rb
  #     root to: 'blogs#index'
  #
  #     # would recognize http://www.example.com/ as
  #     params = { controller: 'blogs', action: 'index' }
  #
  #     # and provide these named routes
  #     root_url   # => 'http://www.example.com/'
  #     root_path  # => '/'
  #
  # Note: when using `controller`, the route is simply named after the method you
  # call on the block parameter rather than map.
  #
  #     # In config/routes.rb
  #     controller :blog do
  #       get 'blog/show'    => :list
  #       get 'blog/delete'  => :delete
  #       get 'blog/edit'    => :edit
  #     end
  #
  #     # provides named routes for show, delete, and edit
  #     link_to @article.title, blog_show_path(id: @article.id)
  #
  # ## Pretty URLs
  #
  # Routes can generate pretty URLs. For example:
  #
  #     get '/articles/:year/:month/:day', to: 'articles#find_by_id', constraints: {
  #       year:       /\d{4}/,
  #       month:      /\d{1,2}/,
  #       day:        /\d{1,2}/
  #     }
  #
  # Using the route above, the URL "http://localhost:3000/articles/2005/11/06"
  # maps to
  #
  #     params = {year: '2005', month: '11', day: '06'}
  #
  # ## Regular Expressions and parameters
  # You can specify a regular expression to define a format for a parameter.
  #
  #     controller 'geocode' do
  #       get 'geocode/:postalcode', to: :show, constraints: {
  #         postalcode: /\d{5}(-\d{4})?/
  #       }
  #     end
  #
  # Constraints can include the 'ignorecase' and 'extended syntax' regular
  # expression modifiers:
  #
  #     controller 'geocode' do
  #       get 'geocode/:postalcode', to: :show, constraints: {
  #         postalcode: /hx\d\d\s\d[a-z]{2}/i
  #       }
  #     end
  #
  #     controller 'geocode' do
  #       get 'geocode/:postalcode', to: :show, constraints: {
  #         postalcode: /# Postalcode format
  #            \d{5} #Prefix
  #            (-\d{4})? #Suffix
  #            /x
  #       }
  #     end
  #
  # Using the multiline modifier will raise an `ArgumentError`. Encoding regular
  # expression modifiers are silently ignored. The match will always use the
  # default encoding or ASCII.
  #
  # ## External redirects
  #
  # You can redirect any path to another path using the redirect helper in your
  # router:
  #
  #     get "/stories", to: redirect("/posts")
  #
  # ## Unicode character routes
  #
  # You can specify unicode character routes in your router:
  #
  #     get "こんにちは", to: "welcome#index"
  #
  # ## Routing to Rack Applications
  #
  # Instead of a String, like `posts#index`, which corresponds to the index action
  # in the PostsController, you can specify any Rack application as the endpoint
  # for a matcher:
  #
  #     get "/application.js", to: Sprockets
  #
  # ## Reloading routes
  #
  # You can reload routes if you feel you must:
  #
  #     Rails.application.reload_routes!
  #
  # This will clear all named routes and reload config/routes.rb if the file has
  # been modified from last load. To absolutely force reloading, use `reload!`.
  #
  # ## Testing Routes
  #
  # The two main methods for testing your routes:
  #
  # ### `assert_routing`
  #
  #     def test_movie_route_properly_splits
  #       opts = {controller: "plugin", action: "checkout", id: "2"}
  #       assert_routing "plugin/checkout/2", opts
  #     end
  #
  # `assert_routing` lets you test whether or not the route properly resolves into
  # options.
  #
  # ### `assert_recognizes`
  #
  #     def test_route_has_options
  #       opts = {controller: "plugin", action: "show", id: "12"}
  #       assert_recognizes opts, "/plugins/show/12"
  #     end
  #
  # Note the subtle difference between the two: `assert_routing` tests that a URL
  # fits options while `assert_recognizes` tests that a URL breaks into parameters
  # properly.
  #
  # In tests you can simply pass the URL or named route to `get` or `post`.
  #
  #     def send_to_jail
  #       get '/jail'
  #       assert_response :success
  #     end
  #
  #     def goes_to_login
  #       get login_url
  #       #...
  #     end
  #
  # ## View a list of all your routes
  #
  #     $ bin/rails routes
  #
  # Target a specific controller with `-c`, or grep routes using `-g`. Useful in
  # conjunction with `--expanded` which displays routes vertically.
  module Routing
    extend ActiveSupport::Autoload

    autoload :Mapper
    autoload :RouteSet
    eager_autoload do
      autoload :RoutesProxy
    end
    autoload :UrlFor
    autoload :PolymorphicRoutes

    SEPARATORS = %w( / . ? ) # :nodoc:
    HTTP_METHODS = [:get, :head, :post, :patch, :put, :delete, :options] # :nodoc:
  end
end
