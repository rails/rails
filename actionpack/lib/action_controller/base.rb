require 'action_controller/request'
require 'action_controller/response'
require 'action_controller/url_rewriter'
require 'action_controller/support/class_attribute_accessors'
require 'action_controller/support/class_inheritable_attributes'
require 'action_controller/support/inflector'
require 'drb'

module ActionController #:nodoc:
  class ActionControllerError < StandardError #:nodoc:
  end
  class SessionRestoreError < ActionControllerError #:nodoc:
  end
  class MissingTemplate < ActionControllerError #:nodoc:
  end
  class UnknownAction < ActionControllerError #:nodoc:
  end
  class MissingFile < ActionControllerError #:nodoc:
  end

  # Action Controllers are made up of one or more actions that performs its purpose and then either renders a template or
  # redirects to another action. An action is defined as a public method on the controller, which will automatically be 
  # made accessible to the web-server through a mod_rewrite mapping. A sample controller could look like this:
  #
  #   class GuestBookController < ActionController::Base
  #     def index
  #       @entries = Entry.find_all
  #     end
  #     
  #     def sign
  #       Entry.create(@params["entry"])
  #       redirect_to :action => "index"
  #     end
  #   end
  #
  #   GuestBookController.template_root = "templates/"
  #   GuestBookController.process_cgi
  #
  # All actions assume that you want to render a template matching the name of the action at the end of the performance
  # unless you tell it otherwise. The index action complies with this assumption, so after populating the @entries instance
  # variable, the GuestBookController will render "templates/guestbook/index.rhtml".
  #
  # Unlike index, the sign action isn't interested in rendering a template. So after performing its main purpose (creating a 
  # new entry in the guest book), it sheds the rendering assumption and initiates a redirect instead. This redirect works by
  # returning an external "302 Moved" HTTP response that takes the user to the index action.
  #
  # The index and sign represent the two basic action archetypes used in Action Controllers. Get-and-show and do-and-redirect.
  # Most actions are variations of these themes.
  #
  # Also note that it's the final call to <tt>process_cgi</tt> that actually initiates the action performance. It will extract
  # request and response objects from the CGI
  #
  # == Requests
  #
  # Requests are processed by the Action Controller framework by extracting the value of the "action" key in the request parameters.
  # This value should hold the name of the action to be performed. Once the action has been identified, the remaining
  # request parameters, the session (if one is available), and the full request with all the http headers are made available to
  # the action through instance variables. Then the action is performed.
  #
  # The full request object is available in @request and is primarily used to query for http headers. These queries are made by
  # accessing the environment hash, like this:
  #
  #   def hello_ip
  #     location = @request.env["REMOTE_IP"]
  #     render_text "Hello stranger from #{location}"
  #   end
  #
  # == Parameters
  #
  # All request parameters whether they come from a GET or POST request, or from the URL, are available through the @params hash.
  # So an action that was performed through /weblog/list?category=All&limit=5 will include { "category" => "All", "limit" => 5 }
  # in @params.
  #
  # It's also possible to construct multi-dimensional parameter hashes by specifying keys using brackets, such as:
  #
  #   <input type="text" name="post[name]" value="david">
  #   <input type="text" name="post[address]" value="hyacintvej">
  #
  # A request stemming from a form holding these inputs will include { "post" # => { "name" => "david", "address" => "hyacintvej" } }.
  # If the address input had been named "post[address][street]", the @params would have included 
  # { "post" => { "address" => { "street" => "hyacintvej" } } }. There's no limit to the depth of the nesting.
  #
  # == Sessions
  #
  # Sessions allows you to store objects in memory between requests. This is useful for objects that are not yet ready to be persisted,
  # such as a Signup object constructed in a multi-paged process, or objects that don't change much and are needed all the time, such
  # as a User object for a system that requires login. The session should not be used, however, as a cache for objects where it's likely 
  # they could be changed unknowingly. It's usually too much work to keep it all synchronized -- something databases already excel at.
  #
  # You can place objects in the session by using the <tt>@session</tt> hash:
  #
  #   @session["person"] = Person.authenticate(user_name, password)
  #
  # And retrieved again through the same hash:
  #
  #   Hello #{@session["person"]}
  #
  # Any object can be placed in the session (as long as it can be Marshalled). But remember that 1000 active sessions each storing a
  # 50kb object could lead to a 50MB memory overhead. In other words, think carefully about size and caching before resorting to the use
  # of the session.
  #
  # == Responses
  #
  # Each action results in a response, which holds the headers and document to be sent to the user's browser. The actual response
  # object is generated automatically through the use of renders and redirects, so it's normally nothing you'll need to be concerned about.
  #
  # == Renders
  #
  # Action Controller sends content to the user by using one of five rendering methods. The most versatile and common is the rendering
  # of a template. Included in the Action Pack is the Action View, which enables rendering of ERb templates. It's automatically configured.
  # The controller passes objects to the view by assigning instance variables:
  #
  #   def show
  #     @post = Post.find(@params["id"])
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
  #     @results = Search.find(@params["query"])
  #     case @results
  #       when 0 then render "weblog/no_results"
  #       when 1 then render_action "show"
  #       when 2..10 then render_action "show_many"
  #     end
  #   end
  #
  # Read more about writing ERb and Builder templates in link:classes/ActionView/Base.html.
  #
  # == Redirects
  #
  # Redirecting is what actions that update the model do when they're done. The <tt>save_post</tt> method shouldn't be responsible for also
  # showing the post once it's saved -- that's the job for <tt>show_post</tt>. So once <tt>save_post</tt> has completed its business, it'll
  # redirect to <tt>show_post</tt>. All redirects are external, which means that when the user refreshes his browser, it's not going to save
  # the post again, but rather just show it one more time.
  # 
  # This sounds fairly simple, but the redirection is complicated by the quest for a phenomenon known as "pretty urls". Instead of accepting
  # the dreadful beings that is "weblog_controller?action=show&post_id=5", Action Controller goes out of its way to represent the former as
  # "/weblog/show/5". And this is even the simple case. As an example of a more advanced pretty url consider
  # "/library/books/ISBN/0743536703/show", which can be mapped to books_controller?action=show&type=ISBN&id=0743536703.
  # 
  # Redirects work by rewriting the URL of the current action. So if the show action was called by "/library/books/ISBN/0743536703/show", 
  # we can redirect to an edit action simply by doing <tt>redirect_to(:action => "edit")</tt>, which could throw the user to 
  # "/library/books/ISBN/0743536703/edit". Naturally, you'll need to setup the .htaccess (or other means of URL rewriting for the web server)
  # to point to the proper controller and action in the first place, but once you have, it can be rewritten with ease.
  # 
  # Let's consider a bunch of examples on how to go from "/library/books/ISBN/0743536703/edit" to somewhere else:
  #
  #   redirect_to(:action => "show", :action_prefix => "XTC/123") =>
  #     "http://www.singlefile.com/library/books/XTC/123/show"
  #
  #   redirect_to(:path_params => {"type" => "EXBC"}) =>
  #     "http://www.singlefile.com/library/books/EXBC/0743536703/show"
  #
  #   redirect_to(:controller => "settings") => 
  #     "http://www.singlefile.com/library/settings/"
  #
  # For more examples of redirecting options, have a look at the unit test in test/controller/url_test.rb. It's very readable and will give
  # you an excellent understanding of the different options and what they do.
  #
  # == Calling multiple redirects or renders
  #
  # The rule for handling calls of multiple redirects and renders is that the first call wins. So in the following example:
  #
  #   def do_something
  #     redirect_to :action => "elsewhere"
  #     render_action "overthere"
  #   end
  #
  # Only the redirect happens. The rendering call is simply ignored.
  #
  # == Environments
  #
  # Action Controller works out of the box with CGI, FastCGI, and mod_ruby. CGI and mod_ruby controllers are triggered just the same using:
  #
  #   WeblogController.process_cgi
  #
  # FastCGI controllers are triggered using:
  #
  #   FCGI.each_cgi{ |cgi| WeblogController.process_cgi(cgi) }
  class Base
    include ClassInheritableAttributes
  
    DEFAULT_RENDER_STATUS_CODE = "200 OK"
  
    DEFAULT_SEND_FILE_OPTIONS = {
      :type         => 'application/octet-stream'.freeze,
      :disposition  => 'attachment'.freeze,
      :stream       => true, 
      :buffer_size  => 4096
    }.freeze

    # Determines whether the view has access to controller internals @request, @response, @session, and @template.
    # By default, it does.
    @@view_controller_internals = true
    cattr_accessor :view_controller_internals

    # All requests are considered local by default, so everyone will be exposed to detailed debugging screens on errors.
    # When the application is ready to go public, this should be set to false, and the protected method <tt>local_request?</tt>
    # should instead be implemented in the controller to determine when debugging screens should be shown.
    @@consider_all_requests_local = true
    cattr_accessor :consider_all_requests_local

    # Template root determines the base from which template references will be made. So a call to render("test/template")
    # will be converted to "#{template_root}/test/template.rhtml".
    cattr_accessor :template_root

    # The logger is used for generating information on the action run-time (including benchmarking) if available.
    # Can be set to nil for no logging. Compatible with both Ruby's own Logger and Log4r loggers.
    cattr_accessor :logger
    
    # Determines which template class should be used by ActionController.
    cattr_accessor :template_class

    # Turn on +ignore_missing_templates+ if you want to unit test actions without making the associated templates.
    cattr_accessor :ignore_missing_templates

    # Holds the request object that's primarily used to get environment variables through access like
    # <tt>@request.env["REQUEST_URI"]</tt>.
    attr_accessor :request
    
    # Holds a hash of all the GET, POST, and Url parameters passed to the action. Accessed like <tt>@params["post_id"]</tt>
    # to get the post_id. No type casts are made, so all values are returned as strings.
    attr_accessor :params
    
    # Holds the response object that's primarily used to set additional HTTP headers through access like 
    # <tt>@response.headers["Cache-Control"] = "no-cache"</tt>. Can also be used to access the final body HTML after a template
    # has been rendered through @response.body -- useful for <tt>after_filter</tt>s that wants to manipulate the output,
    # such as a OutputCompressionFilter.
    attr_accessor :response
    
    # Holds a hash of objects in the session. Accessed like <tt>@session["person"]</tt> to get the object tied to the "person"
    # key. The session will hold any type of object as values, but the key should be a string.
    attr_accessor :session
    
    # Holds a hash of header names and values. Accessed like <tt>@headers["Cache-Control"]</tt> to get the value of the Cache-Control
    # directive. Values should always be specified as strings.
    attr_accessor :headers
    
    # Holds the hash of variables that are passed on to the template class to be made available to the view. This hash
    # is generated by taking a snapshot of all the instance variables in the current scope just before a template is rendered.
    attr_accessor :assigns

    class << self
      # Factory for the standard create, process loop where the controller is discarded after processing.
      def process(request, response) #:nodoc:
        new.process(request, response)
      end
      
      # Converts the class name from something like "OneModule::TwoModule::NeatController" to "NeatController".
      def controller_class_name
        Inflector.demodulize(name)
      end

      # Converts the class name from something like "OneModule::TwoModule::NeatController" to "neat".
      def controller_name
        Inflector.underscore(controller_class_name.sub(/Controller/, ""))
      end
    end

    public
      # Extracts the action_name from the request parameters and performs that action.
      def process(request, response, method = :perform_action, *arguments) #:nodoc:
        initialize_template_class(response)
        assign_shortcuts(request, response)
        initialize_current_url

        log_processing unless logger.nil?
        send(method, *arguments)
        close_session

        return @response
      end

      # Returns an URL that has been rewritten according to the hash of +options+ (for doing a complete redirect, use redirect_to). The
      # valid keys in options are specified below with an example going from "/library/books/ISBN/0743536703/show" (mapped to
      # books_controller?action=show&type=ISBN&id=0743536703):
      #
      #            .---> controller      .--> action
      #   /library/books/ISBN/0743536703/show
      #   '------>      '--------------> action_prefix
      #    controller_prefix (or module)
      #
      # * <tt>:controller_prefix</tt> - specifies the string before the controller name, which would be "/library" for the example.
      #   Called with "/shop" gives "/shop/books/ISBN/0743536703/show".
      # * <tt>:module</tt> - serves as a alias to :controller_prefix (overwrites :controller_prefix unless its nil)
      # * <tt>:controller</tt> - specifies a new controller and clears out everything after the controller name (including the action, 
      #   the pre- and suffix, and all params), so called with "settings" gives "/library/settings/".
      # * <tt>:action_prefix</tt> - specifies the string between the controller name and the action name, which would
      #   be "/ISBN/0743536703" for the example. Called with "/XTC/123/" gives "/library/books/XTC/123/show".
      # * <tt>:action</tt> - specifies a new action, so called with "edit" gives "/library/books/ISBN/0743536703/edit"
      # * <tt>:action_suffix</tt> - specifies the string after the action name, which would be empty for the example.
      #   Called with "/detailed" gives "/library/books/ISBN/0743536703/detailed".
      # * <tt>:path_params</tt> - specifies a hash that contains keys mapping to the request parameter names. In the example, 
      #   { "type" => "ISBN", "id" => "0743536703" } would be the path_params. It serves as another way of replacing part of
      #   the action_prefix or action_suffix. So passing { "type" => "XTC" } would give "/library/books/XTC/0743536703/show".
      # * <tt>:id</tt> - shortcut where ":id => 5" can be used instead of specifying :path_params => { "id" => 5 }.
      #   Called with "123" gives "/library/books/ISBN/123/show".
      # * <tt>:params</tt> - specifies a hash that represents the regular request parameters, such as { "cat" => 1, 
      #   "origin" => "there"} that would give "?cat=1&origin=there". Called with { "temporary" => 1 } in the example would give
      #   "/library/books/ISBN/0743536703/show?temporary=1"
      # * <tt>:anchor</tt> - specifies the anchor name to be appended to the path. Called with "x14" would give
      #   "/library/books/ISBN/0743536703/show#x14"
      # * <tt>:only_path</tt> - if true, returns the absolute URL (omitting the protocol, host name, and port).
      #
      # Naturally, you can combine multiple options in a single redirect. Examples:
      #
      #   redirect_to(:controller_prefix => "/shop", :controller => "settings")
      #   redirect_to(:controller_prefix => false, :controller => "settings") # breaks out of the current controller_prefix
      #   redirect_to(:action => "edit", :id => 3425)
      #   redirect_to(:action => "edit", :path_params => { "type" => "XTC" }, :params => { "temp" => 1})
      #   redirect_to(:action => "publish", :action_prefix => "/published", :anchor => "x14")
      #
      # Instead of passing an options hash, you can also pass a method reference in the form of a symbol. Consider this example:
      #
      #   class WeblogController < ActionController::Base
      #     def update
      #       # do some update
      #       redirect_to :dashboard_url
      #     end
      #     
      #     protected
      #       def dashboard_url
      #         url_for :controller => (@project.active? ? "project" : "account"), :action => "dashboard"
      #       end
      #   end
      def url_for(options = {}, *parameters_for_method_reference) #:doc:
        case options
          when String then options
          when Symbol then send(options, *parameters_for_method_reference)
          when Hash   then @url.rewrite(rewrite_options(options))
        end
      end

      def module_name
        @params["module"]
      end

      # Converts the class name from something like "OneModule::TwoModule::NeatController" to "NeatController".
      def controller_class_name
        self.class.controller_class_name
      end

      # Converts the class name from something like "OneModule::TwoModule::NeatController" to "neat".
      def controller_name
        self.class.controller_name
      end

      # Returns the name of the action this controller is processing.
      def action_name
        @params["action"] || "index"
      end

    protected
      # Renders the template specified by <tt>template_name</tt>, which defaults to the name of the current controller and action.
      # So calling +render+ in WeblogController#show will attempt to render "#{template_root}/weblog/show.rhtml" or 
      # "#{template_root}/weblog/show.rxml" (in that order). The template_root is set on the ActionController::Base class and is 
      # shared by all controllers. It's also possible to pass a status code using the second parameter. This defaults to "200 OK", 
      # but can be changed, such as by calling <tt>render("weblog/error", "500 Error")</tt>.
      def render(template_name = nil, status = nil) #:doc:
        render_file(template_name || default_template_name, status, true)
      end
      
      # Works like render, but instead of requiring a full template name, you can get by with specifying the action name. So calling
      # <tt>render_action "show_many"</tt> in WeblogController#display will render "#{template_root}/weblog/show_many.rhtml" or 
      # "#{template_root}/weblog/show_many.rxml".
      def render_action(action_name, status = nil) #:doc:
        render(default_template_name(action_name), status)
      end
      
      # Works like render, but disregards the template_root and requires a full path to the template that needs to be rendered. Can be
      # used like <tt>render_file "/Users/david/Code/Ruby/template"</tt> to render "/Users/david/Code/Ruby/template.rhtml" or
      # "/Users/david/Code/Ruby/template.rxml".
      def render_file(template_path, status = nil, use_full_path = false) #:doc:
        assert_existance_of_template_file(template_path) if use_full_path
        logger.info("Rendering #{template_path} (#{status || DEFAULT_RENDER_STATUS_CODE})") unless logger.nil?

        add_variables_to_assigns
        render_text(@template.render_file(template_path, use_full_path), status)
      end
      
      # Renders the +template+ string, which is useful for rendering short templates you don't want to bother having a file for. So
      # you'd call <tt>render_template "Hello, <%= @user.name %>"</tt> to greet the current user. Or if you want to render as Builder
      # template, you could do <tt>render_template "xml.h1 @user.name", nil, "rxml"</tt>.
      def render_template(template, status = nil, type = "rhtml") #:doc:
        add_variables_to_assigns
        render_text(@template.render_template(type, template), status)
      end

      # Renders the +text+ string without parsing it through any template engine. Useful for rendering static information as it's
      # considerably faster than rendering through the template engine.
      # Use block for response body if provided (useful for deferred rendering or streaming output).
      def render_text(text = nil, status = nil, &block) #:doc:
        return if performed?
        add_variables_to_assigns
        @response.headers["Status"] = status || DEFAULT_RENDER_STATUS_CODE
        @response.body = block_given? ? block : text
        @performed_render = true
      end
      
      # Renders an empty response that can be used when the request is only interested in triggering an effect. Do note that good
      # HTTP manners mandate that you don't use GET requests to trigger data changes.
      def render_nothing(status = nil)
        render_text "", status
      end

      # Sends the file by streaming it 4096 bytes at a time. This way the
      # whole file doesn't need to be read into memory at once.  This makes
      # it feasible to send even large files.
      #
      # Be careful to sanitize the path parameter if it coming from a web
      # page.  send_file(@params['path']) allows a malicious user to
      # download any file on your server.
      #
      # Options:
      # * <tt>:filename</tt> - suggests a filename for the browser to use.
      #   Defaults to File.basename(path).
      # * <tt>:type</tt> - specifies an HTTP content type.
      #   Defaults to 'application/octet-stream'.
      # * <tt>:disposition</tt> - specifies whether the file will be shown inline or downloaded.  
      #   Valid values are 'inline' and 'attachment' (default).
      # * <tt>:streaming</tt> - whether to send the file to the user agent as it is read (true)
      #   or to read the entire file before sending (false). Defaults to true.
      # * <tt>:buffer_size</tt> - specifies size (in bytes) of the buffer used to stream the file.
      #   Defaults to 4096.
      #
      # The default Content-Type and Content-Disposition headers are
      # set to download arbitrary binary files in as many browsers as
      # possible.  IE versions 4, 5, 5.5, and 6 are all known to have
      # a variety of quirks (especially when downloading over SSL).
      #
      # Simple download:
      #   send_file '/path/to.zip'
      #
      # Show a JPEG in browser:
      #   send_file '/path/to.jpeg', :type => 'image/jpeg', :disposition => 'inline'
      #
      # Read about the other Content-* HTTP headers if you'd like to
      # provide the user with more information (such as Content-Description).
      # http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.11
      #
      # Also be aware that the document may be cached by proxies and browsers.
      # The Pragma and Cache-Control headers declare how the file may be cached
      # by intermediaries.  They default to require clients to validate with
      # the server before releasing cached responses.  See
      # http://www.mnot.net/cache_docs/ for an overview of web caching and
      # http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.9
      # for the Cache-Control header spec.
      def send_file(path, options = {}) #:doc:
        raise MissingFile, "Cannot read file #{path}" unless File.file?(path) and File.readable?(path)

        options[:length]   ||= File.size(path)
        options[:filename] ||= File.basename(path)
        send_file_headers! options

        if options[:stream]
          render_text do
            logger.info "Streaming file #{path}" unless logger.nil?
            len = options[:buffer_size] || 4096
            File.open(path, 'rb') do |file|
              if $stdout.respond_to?(:syswrite)
                begin
                  while true
                    $stdout.syswrite file.sysread(len)
                  end
                rescue EOFError
                end
              else
                while buf = file.read(len)
                  $stdout.write buf
                end
              end
            end
          end
        else
          logger.info "Sending file #{path}" unless logger.nil?
          File.open(path, 'rb') { |file| render_text file.read }
        end
      end

      # Send binary data to the user as a file download.  May set content type, apparent file name,
      # and specify whether to show data inline or download as an attachment.
      #
      # Options:
      # * <tt>:filename</tt> - Suggests a filename for the browser to use.
      # * <tt>:type</tt> - specifies an HTTP content type.
      #   Defaults to 'application/octet-stream'.
      # * <tt>:disposition</tt> - specifies whether the file will be shown inline or downloaded.  
      #   Valid values are 'inline' and 'attachment' (default).
      #
      # Generic data download:
      #   send_data buffer
      #
      # Download a dynamically-generated tarball:
      #   send_data generate_tgz('dir'), :filename => 'dir.tgz'
      #
      # Display an image Active Record in the browser:
      #   send_data image.data, :type => image.content_type, :disposition => 'inline'
      #
      # See +send_file+ for more information on HTTP Content-* headers and caching.
      def send_data(data, options = {}) #:doc:
        logger.info "Sending data #{options[:filename]}" unless logger.nil?
        send_file_headers! options.merge(:length => data.size)
        render_text data
      end

      def rewrite_options(options)
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
      #     { :controller_prefix => @project.active? ? "projects/" : "accounts/" }
      #   end
      #
      # As you can infer from the example, this is mostly useful for situations where you want to centralize dynamic decisions about the
      # urls as they stem from the business domain. Please note that any individual url_for call can always override the defaults set
      # by this method.
      def default_url_options(options) #:doc:
      end
      
      # Redirects the browser to an URL that has been rewritten according to the hash of +options+ using a "302 Moved" HTTP header.
      # See url_for for a description of the valid options.
      def redirect_to(options = {}, *parameters_for_method_reference) #:doc:
        if parameters_for_method_reference.empty?
          @response.redirected_to = options
          redirect_to_url(url_for(options))
        else
          @response.redirected_to, @response.redirected_to_method_params = options, parameters_for_method_reference
          redirect_to_url(url_for(options, *parameters_for_method_reference))
        end
      end
      
      # Redirects the browser to the specified <tt>path</tt> within the current host (specified with a leading /). Used to sidestep
      # the URL rewriting and go directly to a known path. Example: <tt>redirect_to_path "/images/screenshot.jpg"</tt>.
      def redirect_to_path(path) #:doc:
        redirect_to_url(@request.protocol + @request.host_with_port + path)
      end

      # Redirects the browser to the specified <tt>url</tt>. Used to redirect outside of the current application. Example:
      # <tt>redirect_to_url "http://www.rubyonrails.org"</tt>. If the resource has moved permanently, it's possible to pass true as the
      # second parameter and the browser will get "301 Moved Permanently" instead of "302 Found".
      def redirect_to_url(url, permanently = false) #:doc:
        return if performed?
        logger.info("Redirected to #{url}") unless logger.nil?
        @response.redirect(url, permanently)
        @performed_redirect = true
      end

      # Resets the session by clearsing out all the objects stored within and initializing a new session object.
      def reset_session #:doc:
        @request.reset_session
        @session = @request.session
        @response.session = @session
      end
    
      # Deprecated cookie writer method
      def cookie(*options)
        @response.headers["cookie"] << CGI::Cookie.new(*options)
      end

    private
      def initialize_template_class(response)
        begin
          response.template = template_class.new(template_root, {}, self)
        rescue
          raise "You must assign a template class through ActionController.template_class= before processing a request"
        end
        
        @performed_render = @performed_redirect = false
      end
    
      def assign_shortcuts(request, response)
        @request, @params, @cookies = request, request.parameters, request.cookies

        @response         = response
        @response.session = request.session

        @session  = @response.session
        @template = @response.template
        @assigns  = @response.template.assigns        
        @headers  = @response.headers
      end
      
      def initialize_current_url
        @url = UrlRewriter.new(@request, controller_name, action_name)
      end

      def log_processing
        logger.info "\n\nProcessing #{controller_class_name}\##{action_name} (for #{request_origin})"
        logger.info "  Parameters: #{@params.inspect}"
      end
    
      def perform_action
        if action_methods.include?(action_name) || action_methods.include?('method_missing')
          send(action_name)
          render unless performed?
        elsif template_exists? && template_public?
          render
        else
          raise UnknownAction, "No action responded to #{action_name}", caller
        end
      end
      
      def performed?
        @performed_render || @performed_redirect
      end

      def action_methods
        action_controller_classes = self.class.ancestors.reject{ |a| [Object, Kernel].include?(a) }
        action_controller_classes.inject([]) { |action_methods, klass| action_methods + klass.public_instance_methods(false) }
      end

      def add_variables_to_assigns
        add_instance_variables_to_assigns
        add_class_variables_to_assigns if view_controller_internals
      end

      def add_instance_variables_to_assigns
        protected_variables_cache = protected_instance_variables
        instance_variables.each do |var|
          next if protected_variables_cache.include?(var)
          @assigns[var[1..-1]] = instance_variable_get(var)
        end
      end

      def add_class_variables_to_assigns
        %w( template_root logger template_class ignore_missing_templates ).each do |cvar|
          @assigns[cvar] = self.send(cvar)
        end
      end

      def protected_instance_variables
        if view_controller_internals
          [ "@assigns", "@performed_redirect", "@performed_render" ]
        else
          [ "@assigns", "@performed_redirect", "@performed_render", "@request", "@response", "@session", "@cookies", "@template" ]
        end
      end

      def request_origin
        "#{@request.remote_ip} at #{Time.now.to_s}"
      end
      
      def close_session
        @session.close unless @session.nil? || Hash === @session
      end
      
      def template_exists?(template_name = default_template_name)
        @template.file_exists?(template_name)
      end

      def template_public?(template_name = default_template_name)
        @template.file_public?(template_name)
      end

      def assert_existance_of_template_file(template_name)
        unless template_exists?(template_name) || ignore_missing_templates
          full_template_path = @template.send(:full_template_path, template_name, 'rhtml')
          template_type = (template_name =~ /layouts/i) ? 'layout' : 'template'
          raise(MissingTemplate, "Missing #{template_type} #{full_template_path}")
        end
      end

      def send_file_headers!(options)
        options.update(DEFAULT_SEND_FILE_OPTIONS.merge(options))
        [:length, :type, :disposition].each do |arg|
          raise ArgumentError, ":#{arg} option required" if options[arg].nil?
        end

        disposition = options[:disposition].dup || 'attachment'
        disposition <<= %(; filename="#{options[:filename]}") if options[:filename]

        @headers.update(
          'Content-Length'            => options[:length],
          'Content-Type'              => options[:type],
          'Content-Disposition'       => disposition,
          'Content-Transfer-Encoding' => 'binary'
        );
      end

      def default_template_name(default_action_name = action_name)
        module_name ? "#{module_name}/#{controller_name}/#{default_action_name}" : "#{controller_name}/#{default_action_name}"
      end
  end
end
