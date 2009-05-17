require 'set'

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

    def handle_response!(response)
      response.headers['Allow'] ||= allowed_methods_header
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

  class DoubleRenderError < ActionControllerError #:nodoc:
    DEFAULT_MESSAGE = "Render and/or redirect were called multiple times in this action. Please note that you may only call render OR redirect, and at most once per action. Also note that neither redirect nor render terminate execution of the action, so if you want to exit an action after redirecting, you need to do something like \"redirect_to(...) and return\"."

    def initialize(message = nil)
      super(message || DEFAULT_MESSAGE)
    end
  end

  class RedirectBackError < ActionControllerError #:nodoc:
    DEFAULT_MESSAGE = 'No HTTP_REFERER was set in the request to this action, so redirect_to :back could not be called successfully. If this is a test, make sure to specify request.env["HTTP_REFERER"].'

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
    DEFAULT_RENDER_STATUS_CODE = "200 OK"

    include StatusCodes

    cattr_reader :protected_instance_variables
    # Controller specific instance variables which will not be accessible inside views.
    @@protected_instance_variables = %w(@assigns @performed_redirect @performed_render @variables_added @request_origin @url @parent_controller
                                        @action_name @before_filter_chain_aborted @action_cache_path @_session @_headers @_params
                                        @_flash @_response)

    # Prepends all the URL-generating helpers from AssetHelper. This makes it possible to easily move javascripts, stylesheets,
    # and images to a dedicated asset server away from the main web server. Example:
    #   ActionController::Base.asset_host = "http://assets.example.com"
    @@asset_host = ""
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
    @@param_parsers = {}
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
    attr_internal :session

    # Holds a hash of header names and values. Accessed like <tt>headers["Cache-Control"]</tt> to get the value of the Cache-Control
    # directive. Values should always be specified as strings.
    attr_internal :headers

    # Returns the name of the action this controller is processing.
    attr_accessor :action_name

    class << self
      def call(env)
        # HACK: For global rescue to have access to the original request and response
        request = env["action_controller.rescue.request"] ||= Request.new(env)
        response = env["action_controller.rescue.response"] ||= Response.new
        process(request, response)
      end

      # Factory for the standard create, process loop where the controller is discarded after processing.
      def process(request, response) #:nodoc:
        new.process(request, response)
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
      # More methods can be hidden using <tt>hide_actions</tt>.
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

      # Replace sensitive parameter data from the request log.
      # Filters parameters that have any of the arguments as a substring.
      # Looks in all subhashes of the param hash for keys to filter.
      # If a block is given, each key and value of the parameter hash and all
      # subhashes is passed to it, the value or key
      # can be replaced using String#replace or similar method.
      #
      # Examples:
      #   filter_parameter_logging
      #   => Does nothing, just slows the logging process down
      #
      #   filter_parameter_logging :password
      #   => replaces the value to all keys matching /password/i with "[FILTERED]"
      #
      #   filter_parameter_logging :foo, "bar"
      #   => replaces the value to all keys matching /foo|bar/i with "[FILTERED]"
      #
      #   filter_parameter_logging { |k,v| v.reverse! if k =~ /secret/i }
      #   => reverses the value to all keys matching /secret/i
      #
      #   filter_parameter_logging(:foo, "bar") { |k,v| v.reverse! if k =~ /secret/i }
      #   => reverses the value to all keys matching /secret/i, and
      #      replaces the value to all keys matching /foo|bar/i with "[FILTERED]"
      def filter_parameter_logging(*filter_words, &block)
        parameter_filter = Regexp.new(filter_words.collect{ |s| s.to_s }.join('|'), true) if filter_words.length > 0

        define_method(:filter_parameters) do |unfiltered_parameters|
          filtered_parameters = {}

          unfiltered_parameters.each do |key, value|
            if key =~ parameter_filter
              filtered_parameters[key] = '[FILTERED]'
            elsif value.is_a?(Hash)
              filtered_parameters[key] = filter_parameters(value)
            elsif block_given?
              key = key.dup
              value = value.dup if value
              yield key, value
              filtered_parameters[key] = value
            else
              filtered_parameters[key] = value
            end
          end

          filtered_parameters
        end
        protected :filter_parameters
      end

      delegate :exempt_from_layout, :to => 'ActionView::Template'
    end

    public
      # Extracts the action_name from the request parameters and performs that action.
      def process(request, response, method = :perform_action, *arguments) #:nodoc:
        response.request = request

        initialize_template_class(response)
        assign_shortcuts(request, response)
        initialize_current_url
        assign_names

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

    protected
      # Renders the content that will be returned to the browser as the response body.
      #
      # === Rendering an action
      #
      # Action rendering is the most common form and the type used automatically by Action Controller when nothing else is
      # specified. By default, actions are rendered within the current layout (if one exists).
      #
      #   # Renders the template for the action "goal" within the current controller
      #   render :action => "goal"
      #
      #   # Renders the template for the action "short_goal" within the current controller,
      #   # but without the current active layout
      #   render :action => "short_goal", :layout => false
      #
      #   # Renders the template for the action "long_goal" within the current controller,
      #   # but with a custom layout
      #   render :action => "long_goal", :layout => "spectacular"
      #
      # === Rendering partials
      #
      # Partial rendering in a controller is most commonly used together with Ajax calls that only update one or a few elements on a page
      # without reloading. Rendering of partials from the controller makes it possible to use the same partial template in
      # both the full-page rendering (by calling it from within the template) and when sub-page updates happen (from the
      # controller action responding to Ajax calls). By default, the current layout is not used.
      #
      #   # Renders the same partial with a local variable.
      #   render :partial => "person", :locals => { :name => "david" }
      #
      #   # Renders the partial, making @new_person available through
      #   # the local variable 'person'
      #   render :partial => "person", :object => @new_person
      #
      #   # Renders a collection of the same partial by making each element
      #   # of @winners available through the local variable "person" as it
      #   # builds the complete response.
      #   render :partial => "person", :collection => @winners
      #
      #   # Renders a collection of partials but with a custom local variable name
      #   render :partial => "admin_person", :collection => @winners, :as => :person
      #
      #   # Renders the same collection of partials, but also renders the
      #   # person_divider partial between each person partial.
      #   render :partial => "person", :collection => @winners, :spacer_template => "person_divider"
      #
      #   # Renders a collection of partials located in a view subfolder
      #   # outside of our current controller.  In this example we will be
      #   # rendering app/views/shared/_note.r(html|xml)  Inside the partial
      #   # each element of @new_notes is available as the local var "note".
      #   render :partial => "shared/note", :collection => @new_notes
      #
      #   # Renders the partial with a status code of 500 (internal error).
      #   render :partial => "broken", :status => 500
      #
      # Note that the partial filename must also be a valid Ruby variable name,
      # so e.g. 2005 and register-user are invalid.
      #
      #
      # == Automatic etagging
      #
      # Rendering will automatically insert the etag header on 200 OK responses. The etag is calculated using MD5 of the
      # response body. If a request comes in that has a matching etag, the response will be changed to a 304 Not Modified
      # and the response body will be set to an empty string. No etag header will be inserted if it's already set.
      #
      # === Rendering a template
      #
      # Template rendering works just like action rendering except that it takes a path relative to the template root.
      # The current layout is automatically applied.
      #
      #   # Renders the template located in [TEMPLATE_ROOT]/weblog/show.r(html|xml) (in Rails, app/views/weblog/show.erb)
      #   render :template => "weblog/show"
      #
      #   # Renders the template with a local variable
      #   render :template => "weblog/show", :locals => {:customer => Customer.new}
      #
      # === Rendering a file
      #
      # File rendering works just like action rendering except that it takes a filesystem path. By default, the path
      # is assumed to be absolute, and the current layout is not applied.
      #
      #   # Renders the template located at the absolute filesystem path
      #   render :file => "/path/to/some/template.erb"
      #   render :file => "c:/path/to/some/template.erb"
      #
      #   # Renders a template within the current layout, and with a 404 status code
      #   render :file => "/path/to/some/template.erb", :layout => true, :status => 404
      #   render :file => "c:/path/to/some/template.erb", :layout => true, :status => 404
      #
      # === Rendering text
      #
      # Rendering of text is usually used for tests or for rendering prepared content, such as a cache. By default, text
      # rendering is not done within the active layout.
      #
      #   # Renders the clear text "hello world" with status code 200
      #   render :text => "hello world!"
      #
      #   # Renders the clear text "Explosion!"  with status code 500
      #   render :text => "Explosion!", :status => 500
      #
      #   # Renders the clear text "Hi there!" within the current active layout (if one exists)
      #   render :text => "Hi there!", :layout => true
      #
      #   # Renders the clear text "Hi there!" within the layout
      #   # placed in "app/views/layouts/special.r(html|xml)"
      #   render :text => "Hi there!", :layout => "special"
      #
      # === Streaming data and/or controlling the page generation
      #
      # The <tt>:text</tt> option can also accept a Proc object, which can be used to:
      #
      # 1. stream on-the-fly generated data to the browser. Note that you should
      #    use the methods provided by ActionController::Steaming instead if you
      #    want to stream a buffer or a file.
      # 2. manually control the page generation. This should generally be avoided,
      #    as it violates the separation between code and content, and because almost
      #    everything that can be done with this method can also be done more cleanly
      #    using one of the other rendering methods, most notably templates.
      #
      # Two arguments are passed to the proc, a <tt>response</tt> object and an
      # <tt>output</tt> object. The response object is equivalent to the return
      # value of the ActionController::Base#response method, and can be used to
      # control various things in the HTTP response, such as setting the
      # Content-Type header. The output object is an writable <tt>IO</tt>-like
      # object, so one can call <tt>write</tt> and <tt>flush</tt> on it.
      #
      # The following example demonstrates how one can stream a large amount of
      # on-the-fly generated data to the browser:
      #
      #   # Streams about 180 MB of generated data to the browser.
      #   render :text => proc { |response, output|
      #     10_000_000.times do |i|
      #       output.write("This is line #{i}\n")
      #       output.flush
      #     end
      #   }
      #
      # Another example:
      #
      #   # Renders "Hello from code!"
      #   render :text => proc { |response, output| output.write("Hello from code!") }
      #
      # === Rendering XML
      #
      # Rendering XML sets the content type to application/xml.
      #
      #   # Renders '<name>David</name>'
      #   render :xml => {:name => "David"}.to_xml
      #
      # It's not necessary to call <tt>to_xml</tt> on the object you want to render, since <tt>render</tt> will
      # automatically do that for you:
      #
      #   # Also renders '<name>David</name>'
      #   render :xml => {:name => "David"}
      #
      # === Rendering JSON
      #
      # Rendering JSON sets the content type to application/json and optionally wraps the JSON in a callback. It is expected
      # that the response will be parsed (or eval'd) for use as a data structure.
      #
      #   # Renders '{"name": "David"}'
      #   render :json => {:name => "David"}.to_json
      #
      # It's not necessary to call <tt>to_json</tt> on the object you want to render, since <tt>render</tt> will
      # automatically do that for you:
      #
      #   # Also renders '{"name": "David"}'
      #   render :json => {:name => "David"}
      #
      # Sometimes the result isn't handled directly by a script (such as when the request comes from a SCRIPT tag),
      # so the <tt>:callback</tt> option is provided for these cases.
      #
      #   # Renders 'show({"name": "David"})'
      #   render :json => {:name => "David"}.to_json, :callback => 'show'
      #
      # === Rendering an inline template
      #
      # Rendering of an inline template works as a cross between text and action rendering where the source for the template
      # is supplied inline, like text, but its interpreted with ERb or Builder, like action. By default, ERb is used for rendering
      # and the current layout is not used.
      #
      #   # Renders "hello, hello, hello, again"
      #   render :inline => "<%= 'hello, ' * 3 + 'again' %>"
      #
      #   # Renders "<p>Good seeing you!</p>" using Builder
      #   render :inline => "xml.p { 'Good seeing you!' }", :type => :builder
      #
      #   # Renders "hello david"
      #   render :inline => "<%= 'hello ' + name %>", :locals => { :name => "david" }
      #
      # === Rendering inline JavaScriptGenerator page updates
      #
      # In addition to rendering JavaScriptGenerator page updates with Ajax in RJS templates (see ActionView::Base for details),
      # you can also pass the <tt>:update</tt> parameter to +render+, along with a block, to render page updates inline.
      #
      #   render :update do |page|
      #     page.replace_html  'user_list', :partial => 'user', :collection => @users
      #     page.visual_effect :highlight, 'user_list'
      #   end
      #
      # === Rendering vanilla JavaScript
      #
      # In addition to using RJS with render :update, you can also just render vanilla JavaScript with :js.
      #
      #   # Renders "alert('hello')" and sets the mime type to text/javascript
      #   render :js => "alert('hello')"
      #
      # === Rendering with status and location headers
      # All renders take the <tt>:status</tt> and <tt>:location</tt> options and turn them into headers. They can even be used together:
      #
      #   render :xml => post.to_xml, :status => :created, :location => post_url(post)
      def render(options = nil, extra_options = {}, &block) #:doc:
        raise DoubleRenderError, "Can only render or redirect once per action" if performed?

        validate_render_arguments(options, extra_options, block_given?)

        if options.nil?
          options = { :template => default_template, :layout => true }
        elsif options == :update
          options = extra_options.merge({ :update => true })
        elsif options.is_a?(String) || options.is_a?(Symbol)
          case options.to_s.index('/')
          when 0
            extra_options[:file] = options
          when nil
            extra_options[:action] = options
          else
            extra_options[:template] = options
          end

          options = extra_options
        elsif !options.is_a?(Hash)
          extra_options[:partial] = options
          options = extra_options
        end

        layout = pick_layout(options)
        response.layout = layout.path_without_format_and_extension if layout
        logger.info("Rendering template within #{layout.path_without_format_and_extension}") if logger && layout

        if content_type = options[:content_type]
          response.content_type = content_type.to_s
        end

        if location = options[:location]
          response.headers["Location"] = url_for(location)
        end

        if options.has_key?(:text)
          text = layout ? @template.render(options.merge(:text => options[:text], :layout => layout)) : options[:text]
          render_for_text(text, options[:status])

        else
          if file = options[:file]
            render_for_file(file, options[:status], layout, options[:locals] || {})

          elsif template = options[:template]
            render_for_file(template, options[:status], layout, options[:locals] || {})

          elsif inline = options[:inline]
            render_for_text(@template.render(options.merge(:layout => layout)), options[:status])

          elsif action_name = options[:action]
            render_for_file(default_template(action_name.to_s), options[:status], layout)

          elsif xml = options[:xml]
            response.content_type ||= Mime::XML
            render_for_text(xml.respond_to?(:to_xml) ? xml.to_xml : xml, options[:status])

          elsif js = options[:js]
            response.content_type ||= Mime::JS
            render_for_text(js, options[:status])

          elsif options.include?(:json)
            json = options[:json]
            json = ActiveSupport::JSON.encode(json) unless json.is_a?(String)
            json = "#{options[:callback]}(#{json})" unless options[:callback].blank?
            response.content_type ||= Mime::JSON
            render_for_text(json, options[:status])

          elsif options[:partial]
            options[:partial] = default_template_name if options[:partial] == true
            if layout
              render_for_text(@template.render(:text => @template.render(options), :layout => layout), options[:status])
            else
              render_for_text(@template.render(options), options[:status])
            end

          elsif options[:update]
            @template.send(:_evaluate_assigns_and_ivars)

            generator = ActionView::Helpers::PrototypeHelper::JavaScriptGenerator.new(@template, &block)
            response.content_type = Mime::JS
            render_for_text(generator.to_s, options[:status])

          elsif options[:nothing]
            render_for_text(nil, options[:status])

          else
            render_for_file(default_template, options[:status], layout)
          end
        end
      end

      # Renders according to the same rules as <tt>render</tt>, but returns the result in a string instead
      # of sending it as the response body to the browser.
      def render_to_string(options = nil, &block) #:doc:
        render(options, &block)
      ensure
        response.content_type = nil
        erase_render_results
        reset_variables_added_to_assigns
      end

      # Return a response that has no content (merely headers). The options
      # argument is interpreted to be a hash of header names and values.
      # This allows you to easily return a response that consists only of
      # significant headers:
      #
      #   head :created, :location => person_path(@person)
      #
      # It can also be used to return exceptional conditions:
      #
      #   return head(:method_not_allowed) unless request.post?
      #   return head(:bad_request) unless valid_request?
      #   render
      def head(*args)
        if args.length > 2
          raise ArgumentError, "too many arguments to head"
        elsif args.empty?
          raise ArgumentError, "too few arguments to head"
        end
        options = args.extract_options!
        status = interpret_status(args.shift || options.delete(:status) || :ok)

        options.each do |key, value|
          headers[key.to_s.dasherize.split(/-/).map { |v| v.capitalize }.join("-")] = value.to_s
        end

        render :nothing => true, :status => status
      end

      # Clears the rendered results, allowing for another render to be performed.
      def erase_render_results #:nodoc:
        response.body = nil
        @performed_render = false
      end

      # Clears the redirected results from the headers, resets the status to 200 and returns
      # the URL that was used to redirect or nil if there was no redirected URL
      # Note that +redirect_to+ will change the body of the response to indicate a redirection.
      # The response body is not reset here, see +erase_render_results+
      def erase_redirect_results #:nodoc:
        @performed_redirect = false
        response.redirected_to = nil
        response.redirected_to_method_params = nil
        response.status = DEFAULT_RENDER_STATUS_CODE
        response.headers.delete('Location')
      end

      # Erase both render and redirect results
      def erase_results #:nodoc:
        erase_render_results
        erase_redirect_results
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

      # Redirects the browser to the target specified in +options+. This parameter can take one of three forms:
      #
      # * <tt>Hash</tt> - The URL will be generated by calling url_for with the +options+.
      # * <tt>Record</tt> - The URL will be generated by calling url_for with the +options+, which will reference a named URL for that record.
      # * <tt>String</tt> starting with <tt>protocol://</tt> (like <tt>http://</tt>) - Is passed straight through as the target for redirection.
      # * <tt>String</tt> not containing a protocol - The current protocol and host is prepended to the string.
      # * <tt>:back</tt> - Back to the page that issued the request. Useful for forms that are triggered from multiple places.
      #   Short-hand for <tt>redirect_to(request.env["HTTP_REFERER"])</tt>
      #
      # Examples:
      #   redirect_to :action => "show", :id => 5
      #   redirect_to post
      #   redirect_to "http://www.rubyonrails.org"
      #   redirect_to "/images/screenshot.jpg"
      #   redirect_to articles_url
      #   redirect_to :back
      #
      # The redirection happens as a "302 Moved" header unless otherwise specified.
      #
      # Examples:
      #   redirect_to post_url(@post), :status=>:found
      #   redirect_to :action=>'atom', :status=>:moved_permanently
      #   redirect_to post_url(@post), :status=>301
      #   redirect_to :action=>'atom', :status=>302
      #
      # When using <tt>redirect_to :back</tt>, if there is no referrer,
      # RedirectBackError will be raised. You may specify some fallback
      # behavior for this case by rescuing RedirectBackError.
      def redirect_to(options = {}, response_status = {}) #:doc:
        raise ActionControllerError.new("Cannot redirect to nil!") if options.nil?

        if options.is_a?(Hash) && options[:status]
          status = options.delete(:status)
        elsif response_status[:status]
          status = response_status[:status]
        else
          status = 302
        end

        response.redirected_to = options

        case options
          # The scheme name consist of a letter followed by any combination of
          # letters, digits, and the plus ("+"), period ("."), or hyphen ("-")
          # characters; and is terminated by a colon (":").
          when %r{^\w[\w\d+.-]*:.*}
            redirect_to_full_url(options, status)
          when String
            redirect_to_full_url(request.protocol + request.host_with_port + options, status)
          when :back
            if referer = request.headers["Referer"]
              redirect_to(referer, :status=>status)
            else
              raise RedirectBackError
            end
          else
            redirect_to_full_url(url_for(options), status)
        end
      end

      def redirect_to_full_url(url, status)
        raise DoubleRenderError if performed?
        logger.info("Redirected to #{url}") if logger && logger.info?
        response.redirect(url, interpret_status(status))
        @performed_redirect = true
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
        @_session = request.session
      end

    private
      def render_for_file(template_path, status = nil, layout = nil, locals = {}) #:nodoc:
        path = template_path.respond_to?(:path_without_format_and_extension) ? template_path.path_without_format_and_extension : template_path
        logger.info("Rendering #{path}" + (status ? " (#{status})" : '')) if logger
        render_for_text @template.render(:file => template_path, :locals => locals, :layout => layout), status
      end

      def render_for_text(text = nil, status = nil, append_response = false) #:nodoc:
        @performed_render = true

        response.status = interpret_status(status || DEFAULT_RENDER_STATUS_CODE)

        if append_response
          response.body ||= ''
          response.body << text.to_s
        else
          response.body = case text
            when Proc then text
            when nil  then " " # Safari doesn't pass the headers of the return if the response is zero length
            else           text.to_s
          end
        end
      end

      def validate_render_arguments(options, extra_options, has_block)
        if options && (has_block && options != :update) && !options.is_a?(String) && !options.is_a?(Hash) && !options.is_a?(Symbol)
          raise RenderError, "You called render with invalid options : #{options.inspect}"
        end

        if !extra_options.is_a?(Hash)
          raise RenderError, "You called render with invalid options : #{options.inspect}, #{extra_options.inspect}"
        end
      end

      def initialize_template_class(response)
        response.template = ActionView::Base.new(self.class.view_paths, {}, self)
        response.template.helpers.send :include, self.class.master_helper_module
        response.redirected_to = nil
        @performed_render = @performed_redirect = false
      end

      def assign_shortcuts(request, response)
        @_request, @_params = request, request.parameters

        @_response         = response
        @_response.session = request.session

        @_session = @_response.session
        @template = @_response.template

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

      def log_processing_for_parameters
        parameters = respond_to?(:filter_parameters) ? filter_parameters(params) : params.dup
        parameters = parameters.except!(:controller, :action, :format, :_method)

        logger.info "  Parameters: #{parameters.inspect}" unless parameters.empty?
      end

      def default_render #:nodoc:
        render
      end

      def perform_action
        if action_methods.include?(action_name)
          send(action_name)
          default_render unless performed?
        elsif respond_to? :method_missing
          method_missing action_name
          default_render unless performed?
        else
          begin
            default_render
          rescue ActionView::MissingTemplate => e
            # Was the implicit template missing, or was it another template?
            if e.path == default_template_name
              raise UnknownAction, "No action responded to #{action_name}. Actions: #{action_methods.sort.to_sentence(:locale => :en)}", caller
            else
              raise e
            end
          end
        end
      end

      def performed?
        @performed_render || @performed_redirect
      end

      def assign_names
        @action_name = (params['action'] || 'index')
      end

      def action_methods
        self.class.action_methods
      end

      def self.action_methods
        @action_methods ||=
          # All public instance methods of this class, including ancestors
          public_instance_methods(true).map { |m| m.to_s }.to_set -
          # Except for public instance methods of Base and its ancestors
          Base.public_instance_methods(true).map { |m| m.to_s } +
          # Be sure to include shadowed public instance methods of this class
          public_instance_methods(false).map { |m| m.to_s } -
          # And always exclude explicitly hidden actions
          hidden_actions
      end

      def reset_variables_added_to_assigns
        @template.instance_variable_set("@assigns_added", nil)
      end

      def request_origin
        # this *needs* to be cached!
        # otherwise you'd get different results if calling it more than once
        @request_origin ||= "#{request.remote_ip} at #{Time.now.to_s(:db)}"
      end

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
        "#{self.controller_path}/#{action_name}"
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
    [ Filters, Layout, Benchmarking, Rescue, Flash, MimeResponds, Helpers,
      Cookies, Caching, Verification, Streaming, SessionManagement,
      HttpAuthentication::Basic::ControllerMethods, HttpAuthentication::Digest::ControllerMethods,
      RecordIdentifier, RequestForgeryProtection, Translation
    ].each do |mod|
      include mod
    end
  end
end
