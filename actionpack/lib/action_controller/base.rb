# frozen_string_literal: true

# :markup: markdown

require "action_view"
require "action_controller/log_subscriber"
require "action_controller/metal/params_wrapper"

module ActionController
  # # Action Controller Base
  #
  # Action Controllers are the core of a web request in Rails. They are made up of
  # one or more actions that are executed on request and then either it renders a
  # template or redirects to another action. An action is defined as a public
  # method on the controller, which will automatically be made accessible to the
  # web-server through Rails Routes.
  #
  # By default, only the ApplicationController in a Rails application inherits
  # from `ActionController::Base`. All other controllers inherit from
  # ApplicationController. This gives you one class to configure things such as
  # request forgery protection and filtering of sensitive request parameters.
  #
  # A sample controller could look like this:
  #
  #     class PostsController < ApplicationController
  #       def index
  #         @posts = Post.all
  #       end
  #
  #       def create
  #         @post = Post.create params[:post]
  #         redirect_to posts_path
  #       end
  #     end
  #
  # Actions, by default, render a template in the `app/views` directory
  # corresponding to the name of the controller and action after executing code in
  # the action. For example, the `index` action of the PostsController would
  # render the template `app/views/posts/index.html.erb` by default after
  # populating the `@posts` instance variable.
  #
  # Unlike index, the create action will not render a template. After performing
  # its main purpose (creating a new post), it initiates a redirect instead. This
  # redirect works by returning an external `302 Moved` HTTP response that takes
  # the user to the index action.
  #
  # These two methods represent the two basic action archetypes used in Action
  # Controllers: Get-and-show and do-and-redirect. Most actions are variations on
  # these themes.
  #
  # ## Requests
  #
  # For every request, the router determines the value of the `controller` and
  # `action` keys. These determine which controller and action are called. The
  # remaining request parameters, the session (if one is available), and the full
  # request with all the HTTP headers are made available to the action through
  # accessor methods. Then the action is performed.
  #
  # The full request object is available via the request accessor and is primarily
  # used to query for HTTP headers:
  #
  #     def server_ip
  #       location = request.env["REMOTE_ADDR"]
  #       render plain: "This server hosted at #{location}"
  #     end
  #
  # ## Parameters
  #
  # All request parameters, whether they come from a query string in the URL or
  # form data submitted through a POST request are available through the `params`
  # method which returns a hash. For example, an action that was performed through
  # `/posts?category=All&limit=5` will include `{ "category" => "All", "limit" =>
  # "5" }` in `params`.
  #
  # It's also possible to construct multi-dimensional parameter hashes by
  # specifying keys using brackets, such as:
  #
  #     <input type="text" name="post[name]" value="david">
  #     <input type="text" name="post[address]" value="hyacintvej">
  #
  # A request coming from a form holding these inputs will include `{ "post" => {
  # "name" => "david", "address" => "hyacintvej" } }`. If the address input had
  # been named `post[address][street]`, the `params` would have included `{ "post"
  # => { "address" => { "street" => "hyacintvej" } } }`. There's no limit to the
  # depth of the nesting.
  #
  # ## Sessions
  #
  # Sessions allow you to store objects in between requests. This is useful for
  # objects that are not yet ready to be persisted, such as a Signup object
  # constructed in a multi-paged process, or objects that don't change much and
  # are needed all the time, such as a User object for a system that requires
  # login. The session should not be used, however, as a cache for objects where
  # it's likely they could be changed unknowingly. It's usually too much work to
  # keep it all synchronized -- something databases already excel at.
  #
  # You can place objects in the session by using the `session` method, which
  # accesses a hash:
  #
  #     session[:person] = Person.authenticate(user_name, password)
  #
  # You can retrieve it again through the same hash:
  #
  #     "Hello #{session[:person]}"
  #
  # For removing objects from the session, you can either assign a single key to
  # `nil`:
  #
  #     # removes :person from session
  #     session[:person] = nil
  #
  # or you can remove the entire session with `reset_session`.
  #
  # By default, sessions are stored in an encrypted browser cookie (see
  # ActionDispatch::Session::CookieStore). Thus the user will not be able to read
  # or edit the session data. However, the user can keep a copy of the cookie even
  # after it has expired, so you should avoid storing sensitive information in
  # cookie-based sessions.
  #
  # ## Responses
  #
  # Each action results in a response, which holds the headers and document to be
  # sent to the user's browser. The actual response object is generated
  # automatically through the use of renders and redirects and requires no user
  # intervention.
  #
  # ## Renders
  #
  # Action Controller sends content to the user by using one of five rendering
  # methods. The most versatile and common is the rendering of a template.
  # Also included with \Rails is Action View, which enables rendering of ERB
  # templates. It's automatically configured. The controller passes objects to the
  # view by assigning instance variables:
  #
  #     def show
  #       @post = Post.find(params[:id])
  #     end
  #
  # Which are then automatically available to the view:
  #
  #     Title: <%= @post.title %>
  #
  # You don't have to rely on the automated rendering. For example, actions that
  # could result in the rendering of different templates will use the manual
  # rendering methods:
  #
  #     def search
  #       @results = Search.find(params[:query])
  #       case @results.count
  #         when 0 then render action: "no_results"
  #         when 1 then render action: "show"
  #         when 2..10 then render action: "show_many"
  #       end
  #     end
  #
  # Read more about writing ERB and Builder templates in ActionView::Base.
  #
  # ## Redirects
  #
  # Redirects are used to move from one action to another. For example, after a
  # `create` action, which stores a blog entry to the database, we might like to
  # show the user the new entry. Because we're following good DRY principles
  # (Don't Repeat Yourself), we're going to reuse (and redirect to) a `show`
  # action that we'll assume has already been created. The code might look like
  # this:
  #
  #     def create
  #       @entry = Entry.new(params[:entry])
  #       if @entry.save
  #         # The entry was saved correctly, redirect to show
  #         redirect_to action: 'show', id: @entry.id
  #       else
  #         # things didn't go so well, do something else
  #       end
  #     end
  #
  # In this case, after saving our new entry to the database, the user is
  # redirected to the `show` method, which is then executed. Note that this is an
  # external HTTP-level redirection which will cause the browser to make a second
  # request (a GET to the show action), and not some internal re-routing which
  # calls both "create" and then "show" within one request.
  #
  # Learn more about `redirect_to` and what options you have in
  # ActionController::Redirecting.
  #
  # ## Calling multiple redirects or renders
  #
  # An action may perform only a single render or a single redirect. Attempting to
  # do either again will result in a DoubleRenderError:
  #
  #     def do_something
  #       redirect_to action: "elsewhere"
  #       render action: "overthere" # raises DoubleRenderError
  #     end
  #
  # If you need to redirect on the condition of something, then be sure to add
  # "return" to halt execution.
  #
  #     def do_something
  #       if monkeys.nil?
  #         redirect_to(action: "elsewhere")
  #         return
  #       end
  #       render action: "overthere" # won't be called if monkeys is nil
  #     end
  #
  class Base < Metal
    abstract!

    # Shortcut helper that returns all the modules included in
    # ActionController::Base except the ones passed as arguments:
    #
    #     class MyBaseController < ActionController::Metal
    #       ActionController::Base.without_modules(:ParamsWrapper, :Streaming).each do |left|
    #         include left
    #       end
    #     end
    #
    # This gives better control over what you want to exclude and makes it easier to
    # create a bare controller class, instead of listing the modules required
    # manually.
    def self.without_modules(*modules)
      modules = modules.map do |m|
        m.is_a?(Symbol) ? ActionController.const_get(m) : m
      end

      MODULES - modules
    end

    MODULES = [
      AbstractController::Rendering,
      AbstractController::Translation,
      AbstractController::AssetPaths,
      Helpers,
      UrlFor,
      Redirecting,
      ActionView::Layouts,
      Rendering,
      Renderers::All,
      ConditionalGet,
      EtagWithTemplateDigest,
      EtagWithFlash,
      Caching,
      MimeResponds,
      ImplicitRender,
      StrongParameters,
      ParameterEncoding,
      Cookies,
      Flash,
      FormBuilder,
      RequestForgeryProtection,
      ContentSecurityPolicy,
      PermissionsPolicy,
      RateLimiting,
      AllowBrowser,
      Streaming,
      DataStreaming,
      HttpAuthentication::Basic::ControllerMethods,
      HttpAuthentication::Digest::ControllerMethods,
      HttpAuthentication::Token::ControllerMethods,
      DefaultHeaders,
      Logging,
      AbstractController::Callbacks,
      Rescue,
      Instrumentation,
      ParamsWrapper
    ]

    # Note: Documenting these severely degrades the performance of rdoc
    # :stopdoc:
    include AbstractController::Rendering
    include AbstractController::Translation
    include AbstractController::AssetPaths
    include Helpers
    include UrlFor
    include Redirecting
    include ActionView::Layouts
    include Rendering
    include Renderers::All
    include ConditionalGet
    include EtagWithTemplateDigest
    include EtagWithFlash
    include Caching
    include MimeResponds
    include ImplicitRender
    include StrongParameters
    include ParameterEncoding
    include Cookies
    include Flash
    include FormBuilder
    include RequestForgeryProtection
    include ContentSecurityPolicy
    include PermissionsPolicy
    include RateLimiting
    include AllowBrowser
    include Streaming
    include DataStreaming
    include HttpAuthentication::Basic::ControllerMethods
    include HttpAuthentication::Digest::ControllerMethods
    include HttpAuthentication::Token::ControllerMethods
    include DefaultHeaders
    include Logging
    # Before callbacks should also be executed as early as possible, so also include
    # them at the bottom.
    include AbstractController::Callbacks
    # Append rescue at the bottom to wrap as much as possible.
    include Rescue
    # Add instrumentations hooks at the bottom, to ensure they instrument all the
    # methods properly.
    include Instrumentation
    # Params wrapper should come before instrumentation so they are properly showed
    # in logs
    include ParamsWrapper
    # :startdoc:
    setup_renderer!

    # Define some internal variables that should not be propagated to the view.
    PROTECTED_IVARS = AbstractController::Rendering::DEFAULT_PROTECTED_INSTANCE_VARIABLES + %i(
      @_params @_response @_request @_config @_url_options @_action_has_layout @_view_context_class
      @_view_renderer @_lookup_context @_routes @_view_runtime @_db_runtime @_helper_proxy
      @_marked_for_same_origin_verification @_rendered_format
    )

    def _protected_ivars
      PROTECTED_IVARS
    end
    private :_protected_ivars

    ActiveSupport.run_load_hooks(:action_controller_base, self)
    ActiveSupport.run_load_hooks(:action_controller, self)
  end
end
