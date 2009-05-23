require 'action_controller/deprecated'
require 'set'
require 'active_support/core_ext/class/inheritable_attributes'
require 'active_support/core_ext/module/attr_internal'

module ActionController #:nodoc:
  class ActionControllerError < StandardError #:nodoc:
  end

  class SessionRestoreError < ActionControllerError #:nodoc:
  end

  class RenderError < ActionControllerError #:nodoc:
  end

  class RoutingError < ActionControllerError #:nodoc:
    attr_reader :failures
    def initialize(message, failures=[])
      super(message)
      @failures = failures
    end
  end

  class MethodNotAllowed < ActionControllerError #:nodoc:
    attr_reader :allowed_methods

    def initialize(*allowed_methods)
      super("Only #{allowed_methods.to_sentence(:locale => :en)} requests are allowed.")
      @allowed_methods = allowed_methods
    end

    def allowed_methods_header
      allowed_methods.map { |method_symbol| method_symbol.to_s.upcase } * ', '
    end
  end

  class NotImplemented < MethodNotAllowed #:nodoc:
  end

  class UnknownController < ActionControllerError #:nodoc:
  end

  class UnknownAction < ActionControllerError #:nodoc:
  end

  class MissingFile < ActionControllerError #:nodoc:
  end

  class RenderError < ActionControllerError #:nodoc:
  end

  class SessionOverflowError < ActionControllerError #:nodoc:
    DEFAULT_MESSAGE = 'Your session data is larger than the data column in which it is to be stored. You must increase the size of your data column if you intend to store large data.'

    def initialize(message = nil)
      super(message || DEFAULT_MESSAGE)
    end
  end

  class UnknownHttpMethod < ActionControllerError #:nodoc:
  end

  # Action Controllers are the core of a web request in Rails. They are made up of one or more actions that are executed
  # on request and then either render a template or redirect to another action. An action is defined as a public method
  # on the controller, which will automatically be made accessible to the web-server through Rails Routes.
  #
  # A sample controller could look like this:
  #
  #   class GuestBookController < ActionController::Base
  #     def index
  #       @entries = Entry.find(:all)
  #     end
  #
  #     def sign
  #       Entry.create(params[:entry])
  #       redirect_to :action => "index"
  #     end
  #   end
  #
  # Actions, by default, render a template in the <tt>app/views</tt> directory corresponding to the name of the controller and action
  # after executing code in the action. For example, the +index+ action of the GuestBookController would render the
  # template <tt>app/views/guestbook/index.erb</tt> by default after populating the <tt>@entries</tt> instance variable.
  #
  # Unlike index, the sign action will not render a template. After performing its main purpose (creating a
  # new entry in the guest book), it initiates a redirect instead. This redirect works by returning an external
  # "302 Moved" HTTP response that takes the user to the index action.
  #
  # The index and sign represent the two basic action archetypes used in Action Controllers. Get-and-show and do-and-redirect.
  # Most actions are variations of these themes.
  #
  # == Requests
  #
  # Requests are processed by the Action Controller framework by extracting the value of the "action" key in the request parameters.
  # This value should hold the name of the action to be performed. Once the action has been identified, the remaining
  # request parameters, the session (if one is available), and the full request with all the HTTP headers are made available to
  # the action through instance variables. Then the action is performed.
  #
  # The full request object is available with the request accessor and is primarily used to query for HTTP headers. These queries
  # are made by accessing the environment hash, like this:
  #
  #   def server_ip
  #     location = request.env["SERVER_ADDR"]
  #     render :text => "This server hosted at #{location}"
  #   end
  #
  # == Parameters
  #
  # All request parameters, whether they come from a GET or POST request, or from the URL, are available through the params method
  # which returns a hash. For example, an action that was performed through <tt>/weblog/list?category=All&limit=5</tt> will include
  # <tt>{ "category" => "All", "limit" => 5 }</tt> in params.
  #
  # It's also possible to construct multi-dimensional parameter hashes by specifying keys using brackets, such as:
  #
  #   <input type="text" name="post[name]" value="david">
  #   <input type="text" name="post[address]" value="hyacintvej">
  #
  # A request stemming from a form holding these inputs will include <tt>{ "post" => { "name" => "david", "address" => "hyacintvej" } }</tt>.
  # If the address input had been named "post[address][street]", the params would have included
  # <tt>{ "post" => { "address" => { "street" => "hyacintvej" } } }</tt>. There's no limit to the depth of the nesting.
  #
  # == Sessions
  #
  # Sessions allows you to store objects in between requests. This is useful for objects that are not yet ready to be persisted,
  # such as a Signup object constructed in a multi-paged process, or objects that don't change much and are needed all the time, such
  # as a User object for a system that requires login. The session should not be used, however, as a cache for objects where it's likely
  # they could be changed unknowingly. It's usually too much work to keep it all synchronized -- something databases already excel at.
  #
  # You can place objects in the session by using the <tt>session</tt> method, which accesses a hash:
  #
  #   session[:person] = Person.authenticate(user_name, password)
  #
  # And retrieved again through the same hash:
  #
  #   Hello #{session[:person]}
  #
  # For removing objects from the session, you can either assign a single key to +nil+:
  #
  #   # removes :person from session
  #   session[:person] = nil
  #
  # or you can remove the entire session with +reset_session+.
  #
  # Sessions are stored by default in a browser cookie that's cryptographically signed, but unencrypted.
  # This prevents the user from tampering with the session but also allows him to see its contents.
  #
  # Do not put secret information in cookie-based sessions!
  #
  # Other options for session storage are:
  #
  # * ActiveRecord::SessionStore - Sessions are stored in your database, which works better than PStore with multiple app servers and,
  #   unlike CookieStore, hides your session contents from the user. To use ActiveRecord::SessionStore, set
  #
  #     config.action_controller.session_store = :active_record_store
  #
  #   in your <tt>config/environment.rb</tt> and run <tt>rake db:sessions:create</tt>.
  #
  # * MemCacheStore - Sessions are stored as entries in your memcached cache.
  #   Set the session store type in <tt>config/environment.rb</tt>:
  #
  #     config.action_controller.session_store = :mem_cache_store
  #
  #   This assumes that memcached has been installed and configured properly.
  #   See the MemCacheStore docs for more information.
  #
  # == Responses
  #
  # Each action results in a response, which holds the headers and document to be sent to the user's browser. The actual response
  # object is generated automatically through the use of renders and redirects and requires no user intervention.
  #
  # == Renders
  #
  # Action Controller sends content to the user by using one of five rendering methods. The most versatile and common is the rendering
  # of a template. Included in the Action Pack is the Action View, which enables rendering of ERb templates. It's automatically configured.
  # The controller passes objects to the view by assigning instance variables:
  #
  #   def show
  #     @post = Post.find(params[:id])
  #   end
  #
  # Which are then automatically available to the view:
  #
  #   Title: <%= @post.title %>
  #
  # You don't have to rely on the automated rendering. Especially actions that could result in the rendering of different templates will use
  # the manual rendering methods:
  #
  #   def search
  #     @results = Search.find(params[:query])
  #     case @results
  #       when 0 then render :action => "no_results"
  #       when 1 then render :action => "show"
  #       when 2..10 then render :action => "show_many"
  #     end
  #   end
  #
  # Read more about writing ERb and Builder templates in link:classes/ActionView/Base.html.
  #
  # == Redirects
  #
  # Redirects are used to move from one action to another. For example, after a <tt>create</tt> action, which stores a blog entry to a database,
  # we might like to show the user the new entry. Because we're following good DRY principles (Don't Repeat Yourself), we're going to reuse (and redirect to)
  # a <tt>show</tt> action that we'll assume has already been created. The code might look like this:
  #
  #   def create
  #     @entry = Entry.new(params[:entry])
  #     if @entry.save
  #       # The entry was saved correctly, redirect to show
  #       redirect_to :action => 'show', :id => @entry.id
  #     else
  #       # things didn't go so well, do something else
  #     end
  #   end
  #
  # In this case, after saving our new entry to the database, the user is redirected to the <tt>show</tt> method which is then executed.
  #
  # == Calling multiple redirects or renders
  #
  # An action may contain only a single render or a single redirect. Attempting to try to do either again will result in a DoubleRenderError:
  #
  #   def do_something
  #     redirect_to :action => "elsewhere"
  #     render :action => "overthere" # raises DoubleRenderError
  #   end
  #
  # If you need to redirect on the condition of something, then be sure to add "and return" to halt execution.
  #
  #   def do_something
  #     redirect_to(:action => "elsewhere") and return if monkeys.nil?
  #     render :action => "overthere" # won't be called if monkeys is nil
  #   end
  #
  class Base

    include ActionDispatch::StatusCodes

    cattr_reader :protected_instance_variables
    # Controller specific instance variables which will not be accessible inside views.
    @@protected_instance_variables = %w(@assigns @performed_redirect @performed_render @variables_added @request_origin @url @parent_controller
                                        @action_name @before_filter_chain_aborted @action_cache_path @_headers @_params
                                        @_flash @_response)

    # Prepends all the URL-generating helpers from AssetHelper. This makes it possible to easily move javascripts, stylesheets,
    # and images to a dedicated asset server away from the main web server. Example:
    #   ActionController::Base.asset_host = "http://assets.example.com"
    cattr_accessor :asset_host

    # All requests are considered local by default, so everyone will be exposed to detailed debugging screens on errors.
    # When the application is ready to go public, this should be set to false, and the protected method <tt>local_request?</tt>
    # should instead be implemented in the controller to determine when debugging screens should be shown.
    @@consider_all_requests_local = true
    cattr_accessor :consider_all_requests_local

    # Indicates whether to allow concurrent action processing. Your
    # controller actions and any other code they call must also behave well
    # when called from concurrent threads. Turned off by default.
    @@allow_concurrency = false
    cattr_accessor :allow_concurrency

    # Modern REST web services often need to submit complex data to the web application.
    # The <tt>@@param_parsers</tt> hash lets you register handlers which will process the HTTP body and add parameters to the
    # <tt>params</tt> hash. These handlers are invoked for POST and PUT requests.
    #
    # By default <tt>application/xml</tt> is enabled. A XmlSimple class with the same param name as the root will be instantiated
    # in the <tt>params</tt>. This allows XML requests to mask themselves as regular form submissions, so you can have one
    # action serve both regular forms and web service requests.
    #
    # Example of doing your own parser for a custom content type:
    #
    #   ActionController::Base.param_parsers[Mime::Type.lookup('application/atom+xml')] = Proc.new do |data|
    #      node = REXML::Document.new(post)
    #     { node.root.name => node.root }
    #   end
    #
    # Note: Up until release 1.1 of Rails, Action Controller would default to using XmlSimple configured to discard the
    # root node for such requests. The new default is to keep the root, such that "<r><name>David</name></r>" results
    # in <tt>params[:r][:name]</tt> for "David" instead of <tt>params[:name]</tt>. To get the old behavior, you can
    # re-register XmlSimple as application/xml handler ike this:
    #
    #   ActionController::Base.param_parsers[Mime::XML] =
    #     Proc.new { |data| XmlSimple.xml_in(data, 'ForceArray' => false) }
    #
    # A YAML parser is also available and can be turned on with:
    #
    #   ActionController::Base.param_parsers[Mime::YAML] = :yaml
    @@param_parsers = { Mime::MULTIPART_FORM   => :multipart_form,
                        Mime::URL_ENCODED_FORM => :url_encoded_form,
                        Mime::XML              => :xml_simple,
                        Mime::JSON             => :json }
    cattr_accessor :param_parsers

    # Controls the default charset for all renders.
    @@default_charset = "utf-8"
    cattr_accessor :default_charset

    # The logger is used for generating information on the action run-time (including benchmarking) if available.
    # Can be set to nil for no logging. Compatible with both Ruby's own Logger and Log4r loggers.
    cattr_accessor :logger

    # Controls the resource action separator
    @@resource_action_separator = "/"
    cattr_accessor :resource_action_separator

    # Allow to override path names for default resources' actions
    @@resources_path_names = { :new => 'new', :edit => 'edit' }
    cattr_accessor :resources_path_names

    # Sets the token parameter name for RequestForgery. Calling +protect_from_forgery+
    # sets it to <tt>:authenticity_token</tt> by default.
    cattr_accessor :request_forgery_protection_token

    # Controls the IP Spoofing check when determining the remote IP.
    @@ip_spoofing_check = true
    cattr_accessor :ip_spoofing_check

    # Indicates whether or not optimise the generated named
    # route helper methods
    cattr_accessor :optimise_named_routes
    self.optimise_named_routes = true

    # Indicates whether the response format should be determined by examining the Accept HTTP header,
    # or by using the simpler params + ajax rules.
    #
    # If this is set to +true+ (the default) then +respond_to+ and +Request#format+ will take the Accept
    # header into account.  If it is set to false then the request format will be determined solely
    # by examining params[:format].  If params format is missing, the format will be either HTML or
    # Javascript depending on whether the request is an AJAX request.
    cattr_accessor :use_accept_header
    self.use_accept_header = true

    # Controls whether request forgergy protection is turned on or not. Turned off by default only in test mode.
    class_inheritable_accessor :allow_forgery_protection
    self.allow_forgery_protection = true

    # If you are deploying to a subdirectory, you will need to set
    # <tt>config.action_controller.relative_url_root</tt>
    # This defaults to ENV['RAILS_RELATIVE_URL_ROOT']
    cattr_accessor :relative_url_root
    self.relative_url_root = ENV['RAILS_RELATIVE_URL_ROOT']

    # Holds the request object that's primarily used to get environment variables through access like
    # <tt>request.env["REQUEST_URI"]</tt>.
    attr_internal :request

    # Holds a hash of all the GET, POST, and Url parameters passed to the action. Accessed like <tt>params["post_id"]</tt>
    # to get the post_id. No type casts are made, so all values are returned as strings.
    attr_internal :params

    # Holds the response object that's primarily used to set additional HTTP headers through access like
    # <tt>response.headers["Cache-Control"] = "no-cache"</tt>. Can also be used to access the final body HTML after a template
    # has been rendered through response.body -- useful for <tt>after_filter</tt>s that wants to manipulate the output,
    # such as a OutputCompressionFilter.
    attr_internal :response

    # Holds a hash of objects in the session. Accessed like <tt>session[:person]</tt> to get the object tied to the "person"
    # key. The session will hold any type of object as values, but the key should be a string or symbol.
    def session
      request.session
    end

    # Holds a hash of header names and values. Accessed like <tt>headers["Cache-Control"]</tt> to get the value of the Cache-Control
    # directive. Values should always be specified as strings.
    attr_internal :headers

    # Returns the name of the action this controller is processing.
    attr_accessor :action_name

    attr_reader :template

    def action(name, env)
      request  = ActionDispatch::Request.new(env)
      response = ActionDispatch::Response.new
      self.action_name = name && name.to_s
      process(request, response).to_a
    end


    class << self
      def action(name = nil)
        @actions ||= {}
        @actions[name] ||= proc do |env|
          new.action(name, env)
        end
      end
      
      # Converts the class name from something like "OneModule::TwoModule::NeatController" to "NeatController".
      def controller_class_name
        @controller_class_name ||= name.demodulize
      end

      # Converts the class name from something like "OneModule::TwoModule::NeatController" to "neat".
      def controller_name
        @controller_name ||= controller_class_name.sub(/Controller$/, '').underscore
      end

      # Converts the class name from something like "OneModule::TwoModule::NeatController" to "one_module/two_module/neat".
      def controller_path
        @controller_path ||= name.gsub(/Controller$/, '').underscore
      end

      # Return an array containing the names of public methods that have been marked hidden from the action processor.
      # By default, all methods defined in ActionController::Base and included modules are hidden.
      # More methods can be hidden using <tt>hide_action</tt>.
      def hidden_actions
        read_inheritable_attribute(:hidden_actions) || write_inheritable_attribute(:hidden_actions, [])
      end

      # Hide each of the given methods from being callable as actions.
      def hide_action(*names)
        write_inheritable_attribute(:hidden_actions, hidden_actions | names.map { |name| name.to_s })
      end

      # View load paths determine the bases from which template references can be made. So a call to
      # render("test/template") will be looked up in the view load paths array and the closest match will be
      # returned.
      def view_paths
        if defined? @view_paths
          @view_paths
        else
          superclass.view_paths
        end
      end

      def view_paths=(value)
        @view_paths = ActionView::Base.process_view_paths(value) if value
      end

      # Adds a view_path to the front of the view_paths array.
      # If the current class has no view paths, copy them from
      # the superclass.  This change will be visible for all future requests.
      #
      #   ArticleController.prepend_view_path("views/default")
      #   ArticleController.prepend_view_path(["views/default", "views/custom"])
      #
      def prepend_view_path(path)
        @view_paths = superclass.view_paths.dup if !defined?(@view_paths) || @view_paths.nil?
        @view_paths.unshift(*path)
      end

      # Adds a view_path to the end of the view_paths array.
      # If the current class has no view paths, copy them from
      # the superclass. This change will be visible for all future requests.
      #
      #   ArticleController.append_view_path("views/default")
      #   ArticleController.append_view_path(["views/default", "views/custom"])
      #
      def append_view_path(path)
        @view_paths = superclass.view_paths.dup if @view_paths.nil?
        @view_paths.push(*path)
      end
      
      @@exempt_from_layout = [ActionView::TemplateHandlers::RJS]
      
      def exempt_from_layout(*types)
        types.each do |type|
          @@exempt_from_layout << 
            ActionView::Template.handler_class_for_extension(type)
        end
        
        @@exempt_from_layout
      end

    end

    public
      def call(env)
        request = ActionDispatch::Request.new(env)
        response = ActionDispatch::Response.new
        process(request, response).to_a
      end

      # Extracts the action_name from the request parameters and performs that action.
      def process(request, response, method = :perform_action, *arguments) #:nodoc:
        response.request = request

        assign_shortcuts(request, response)
        initialize_template_class(response)
        initialize_current_url

        log_processing
        send(method, *arguments)

        send_response
      ensure
        process_cleanup
      end

      def send_response
        response.prepare!
        response
      end

      # Returns a URL that has been rewritten according to the options hash and the defined routes.
      # (For doing a complete redirect, use +redirect_to+).
      #
      # <tt>url_for</tt> is used to:
      #
      # All keys given to +url_for+ are forwarded to the Route module, save for the following:
      # * <tt>:anchor</tt> - Specifies the anchor name to be appended to the path. For example,
      #   <tt>url_for :controller => 'posts', :action => 'show', :id => 10, :anchor => 'comments'</tt>
      #   will produce "/posts/show/10#comments".
      # * <tt>:only_path</tt> - If true, returns the relative URL (omitting the protocol, host name, and port) (<tt>false</tt> by default).
      # * <tt>:trailing_slash</tt> - If true, adds a trailing slash, as in "/archive/2005/". Note that this
      #   is currently not recommended since it breaks caching.
      # * <tt>:host</tt> - Overrides the default (current) host if provided.
      # * <tt>:protocol</tt> - Overrides the default (current) protocol if provided.
      # * <tt>:port</tt> - Optionally specify the port to connect to.
      # * <tt>:user</tt> - Inline HTTP authentication (only plucked out if <tt>:password</tt> is also present).
      # * <tt>:password</tt> - Inline HTTP authentication (only plucked out if <tt>:user</tt> is also present).
      # * <tt>:skip_relative_url_root</tt> - If true, the url is not constructed using the +relative_url_root+
      #   of the request so the path will include the web server relative installation directory.
      #
      # The URL is generated from the remaining keys in the hash. A URL contains two key parts: the <base> and a query string.
      # Routes composes a query string as the key/value pairs not included in the <base>.
      #
      # The default Routes setup supports a typical Rails path of "controller/action/id" where action and id are optional, with
      # action defaulting to 'index' when not given. Here are some typical url_for statements and their corresponding URLs:
      #
      #   url_for :controller => 'posts', :action => 'recent'                # => 'proto://host.com/posts/recent'
      #   url_for :controller => 'posts', :action => 'index'                 # => 'proto://host.com/posts'
      #   url_for :controller => 'posts', :action => 'index', :port=>'8033'  # => 'proto://host.com:8033/posts'
      #   url_for :controller => 'posts', :action => 'show', :id => 10       # => 'proto://host.com/posts/show/10'
      #   url_for :controller => 'posts', :user => 'd', :password => '123'   # => 'proto://d:123@host.com/posts'
      #
      # When generating a new URL, missing values may be filled in from the current request's parameters. For example,
      # <tt>url_for :action => 'some_action'</tt> will retain the current controller, as expected. This behavior extends to
      # other parameters, including <tt>:controller</tt>, <tt>:id</tt>, and any other parameters that are placed into a Route's
      # path.
      #  
      # The URL helpers such as <tt>url_for</tt> have a limited form of memory: when generating a new URL, they can look for
      # missing values in the current request's parameters. Routes attempts to guess when a value should and should not be
      # taken from the defaults. There are a few simple rules on how this is performed:
      #
      # * If the controller name begins with a slash no defaults are used:
      #
      #     url_for :controller => '/home'
      #
      #   In particular, a leading slash ensures no namespace is assumed. Thus,
      #   while <tt>url_for :controller => 'users'</tt> may resolve to
      #   <tt>Admin::UsersController</tt> if the current controller lives under
      #   that module, <tt>url_for :controller => '/users'</tt> ensures you link
      #   to <tt>::UsersController</tt> no matter what.
      # * If the controller changes, the action will default to index unless provided
      #
      # The final rule is applied while the URL is being generated and is best illustrated by an example. Let us consider the
      # route given by <tt>map.connect 'people/:last/:first/:action', :action => 'bio', :controller => 'people'</tt>.
      #
      # Suppose that the current URL is "people/hh/david/contacts". Let's consider a few different cases of URLs which are generated
      # from this page.
      #
      # * <tt>url_for :action => 'bio'</tt> -- During the generation of this URL, default values will be used for the first and
      # last components, and the action shall change. The generated URL will be, "people/hh/david/bio".
      # * <tt>url_for :first => 'davids-little-brother'</tt> This generates the URL 'people/hh/davids-little-brother' -- note
      #   that this URL leaves out the assumed action of 'bio'.
      #
      # However, you might ask why the action from the current request, 'contacts', isn't carried over into the new URL. The
      # answer has to do with the order in which the parameters appear in the generated path. In a nutshell, since the
      # value that appears in the slot for <tt>:first</tt> is not equal to default value for <tt>:first</tt> we stop using
      # defaults. On its own, this rule can account for much of the typical Rails URL behavior.
      #  
      # Although a convenience, defaults can occasionally get in your way. In some cases a default persists longer than desired.
      # The default may be cleared by adding <tt>:name => nil</tt> to <tt>url_for</tt>'s options.
      # This is often required when writing form helpers, since the defaults in play may vary greatly depending upon where the
      # helper is used from. The following line will redirect to PostController's default action, regardless of the page it is
      # displayed on:
      #
      #   url_for :controller => 'posts', :action => nil
      #
      # If you explicitly want to create a URL that's almost the same as the current URL, you can do so using the
      # <tt>:overwrite_params</tt> options. Say for your posts you have different views for showing and printing them.
      # Then, in the show view, you get the URL for the print view like this
      #
      #   url_for :overwrite_params => { :action => 'print' }
      #
      # This takes the current URL as is and only exchanges the action. In contrast, <tt>url_for :action => 'print'</tt>
      # would have slashed-off the path components after the changed action.
      def url_for(options = {})
        options ||= {}
        case options
          when String
            options
          when Hash
            @url.rewrite(rewrite_options(options))
          else
            polymorphic_url(options)
        end
      end

      # Converts the class name from something like "OneModule::TwoModule::NeatController" to "NeatController".
      def controller_class_name
        self.class.controller_class_name
      end

      # Converts the class name from something like "OneModule::TwoModule::NeatController" to "neat".
      def controller_name
        self.class.controller_name
      end

      # Converts the class name from something like "OneModule::TwoModule::NeatController" to "one_module/two_module/neat".
      def controller_path
        self.class.controller_path
      end

      def session_enabled?
        ActiveSupport::Deprecation.warn("Sessions are now lazy loaded. So if you don't access them, consider them disabled.", caller)
      end

      self.view_paths = []

      # View load paths for controller.
      def view_paths
        @template.view_paths
      end

      def view_paths=(value)
        @template.view_paths = ActionView::Base.process_view_paths(value)
      end

      # Adds a view_path to the front of the view_paths array.
      # This change affects the current request only.
      #
      #   self.prepend_view_path("views/default")
      #   self.prepend_view_path(["views/default", "views/custom"])
      #
      def prepend_view_path(path)
        @template.view_paths.unshift(*path)
      end

      # Adds a view_path to the end of the view_paths array.
      # This change affects the current request only.
      #
      #   self.append_view_path("views/default")
      #   self.append_view_path(["views/default", "views/custom"])
      #
      def append_view_path(path)
        @template.view_paths.push(*path)
      end

      def rewrite_options(options) #:nodoc:
        if defaults = default_url_options(options)
          defaults.merge(options)
        else
          options
        end
      end

      # Overwrite to implement a number of default options that all url_for-based methods will use. The default options should come in
      # the form of a hash, just like the one you would use for url_for directly. Example:
      #
      #   def default_url_options(options)
      #     { :project => @project.active? ? @project.url_name : "unknown" }
      #   end
      #
      # As you can infer from the example, this is mostly useful for situations where you want to centralize dynamic decisions about the
      # urls as they stem from the business domain. Please note that any individual url_for call can always override the defaults set
      # by this method.
      def default_url_options(options = nil)
      end

      # Sets the etag and/or last_modified on the response and checks it against
      # the client request. If the request doesn't match the options provided, the
      # request is considered stale and should be generated from scratch. Otherwise,
      # it's fresh and we don't need to generate anything and a reply of "304 Not Modified" is sent.
      #
      # Parameters:
      # * <tt>:etag</tt>
      # * <tt>:last_modified</tt> 
      # * <tt>:public</tt> By default the Cache-Control header is private, set this to true if you want your application to be cachable by other devices (proxy caches).
      #
      # Example:
      #
      #   def show
      #     @article = Article.find(params[:id])
      #
      #     if stale?(:etag => @article, :last_modified => @article.created_at.utc)
      #       @statistics = @article.really_expensive_call
      #       respond_to do |format|
      #         # all the supported formats
      #       end
      #     end
      #   end
      def stale?(options)
        fresh_when(options)
        !request.fresh?(response)
      end

      # Sets the etag, last_modified, or both on the response and renders a
      # "304 Not Modified" response if the request is already fresh.
      #
      # Parameters:
      # * <tt>:etag</tt>
      # * <tt>:last_modified</tt> 
      # * <tt>:public</tt> By default the Cache-Control header is private, set this to true if you want your application to be cachable by other devices (proxy caches).
      #
      # Example:
      #
      #   def show
      #     @article = Article.find(params[:id])
      #     fresh_when(:etag => @article, :last_modified => @article.created_at.utc, :public => true)
      #   end
      #
      # This will render the show template if the request isn't sending a matching etag or
      # If-Modified-Since header and just a "304 Not Modified" response if there's a match.
      #
      def fresh_when(options)
        options.assert_valid_keys(:etag, :last_modified, :public)

        response.etag          = options[:etag]          if options[:etag]
        response.last_modified = options[:last_modified] if options[:last_modified]
        
        if options[:public] 
          cache_control = response.headers["Cache-Control"].split(",").map {|k| k.strip }
          cache_control.delete("private")
          cache_control.delete("no-cache")
          cache_control << "public"
          response.headers["Cache-Control"] = cache_control.join(', ')
        end

        if request.fresh?(response)
          head :not_modified
        end
      end

      # Sets a HTTP 1.1 Cache-Control header. Defaults to issuing a "private" instruction, so that
      # intermediate caches shouldn't cache the response.
      #
      # Examples:
      #   expires_in 20.minutes
      #   expires_in 3.hours, :public => true
      #   expires in 3.hours, 'max-stale' => 5.hours, :public => true
      #
      # This method will overwrite an existing Cache-Control header.
      # See http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html for more possibilities.
      def expires_in(seconds, options = {}) #:doc:
        cache_control = response.headers["Cache-Control"].split(",").map {|k| k.strip }

        cache_control << "max-age=#{seconds}"
        cache_control.delete("no-cache")
        if options[:public]
          cache_control.delete("private")
          cache_control << "public"
        else
          cache_control << "private"
        end
        
        # This allows for additional headers to be passed through like 'max-stale' => 5.hours
        cache_control += options.symbolize_keys.reject{|k,v| k == :public || k == :private }.map{ |k,v| v == true ? k.to_s : "#{k.to_s}=#{v.to_s}"}
        
        response.headers["Cache-Control"] = cache_control.join(', ')
      end

      # Sets a HTTP 1.1 Cache-Control header of "no-cache" so no caching should occur by the browser or
      # intermediate caches (like caching proxy servers).
      def expires_now #:doc:
        response.headers["Cache-Control"] = "no-cache"
      end

      # Resets the session by clearing out all the objects stored within and initializing a new session object.
      def reset_session #:doc:
        request.reset_session
      end

    private
      def _process_options(options)
        if content_type = options[:content_type]
          response.content_type = content_type.to_s
        end

        if location = options[:location]
          response.headers["Location"] = url_for(location)
        end

        response.status = interpret_status(options[:status] || DEFAULT_RENDER_STATUS_CODE)
      end

      def initialize_template_class(response)
        @template = ActionView::Base.new(self.class.view_paths, {}, self, formats)
        response.template = @template if response.respond_to?(:template=)
        @template.helpers.send :include, self.class.master_helper_module
        @performed_render = @performed_redirect = false
      end

      def assign_shortcuts(request, response)
        @_request, @_response, @_params = request, response, request.parameters
        @_headers = @_response.headers
      end

      def initialize_current_url
        @url = UrlRewriter.new(request, params.clone)
      end

      def log_processing
        if logger && logger.info?
          log_processing_for_request_id
          log_processing_for_parameters
        end
      end

      def log_processing_for_request_id
        request_id = "\n\nProcessing #{self.class.name}\##{action_name} "
        request_id << "to #{params[:format]} " if params[:format]
        request_id << "(for #{request_origin}) [#{request.method.to_s.upcase}]"

        logger.info(request_id)
      end

      def default_render #:nodoc:
        render
      end

      def perform_action
        if called = action_methods.include?(action_name)
          ret = send(action_name)
        elsif called = respond_to?(:method_missing)
          ret = method_missing(action_name)
        end
        
        return (performed? ? ret : default_render) if called
        
        begin
          view_paths.find_by_parts(action_name, {:formats => formats, :locales => [I18n.locale]}, controller_path)
        rescue => e
          raise UnknownAction, "No action responded to #{action_name}. Actions: " +
            "#{action_methods.sort.to_sentence}", caller
        end
        
        default_render
      end

      # Returns true if a render or redirect has already been performed.
      def performed?
        @performed_render || @performed_redirect
      end

      def reset_variables_added_to_assigns
        @template.instance_variable_set("@assigns_added", nil)
      end

      def request_origin
        # this *needs* to be cached!
        # otherwise you'd get different results if calling it more than once
        @request_origin ||= "#{request.remote_ip} at #{Time.now.to_s(:db)}"
      end

      # Returns the request URI used to get to the current location
      def complete_request_uri
        "#{request.protocol}#{request.host}#{request.request_uri}"
      end

      def default_template(action_name = self.action_name)
        self.view_paths.find_template(default_template_name(action_name), default_template_format)
      end

      def default_template_name(action_name = self.action_name)
        if action_name
          action_name = action_name.to_s
          if action_name.include?('/') && template_path_includes_controller?(action_name)
            action_name = strip_out_controller(action_name)
          end
        end
        "#{controller_path}/#{action_name}"
      end

      def strip_out_controller(path)
        path.split('/', 2).last
      end

      def template_path_includes_controller?(path)
        self.controller_path.split('/')[-1] == path.split('/')[0]
      end

      def process_cleanup
      end
  end

  Base.class_eval do
    [ Filters, Layout, Renderer, Redirector, Responder, Benchmarking, Rescue, Flash, MimeResponds, Helpers,
      Cookies, Caching, Verification, Streaming, SessionManagement,
      HttpAuthentication::Basic::ControllerMethods, HttpAuthentication::Digest::ControllerMethods, RecordIdentifier,
      RequestForgeryProtection, Translation, FilterParameterLogging
    ].each do |mod|
      include mod
    end
  end
end
