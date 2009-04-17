# AUTHOR: blink <blinketje@gmail.com>; blink#ruby-lang@irc.freenode.net

gem 'ruby-openid', '~> 2' if defined? Gem
require 'rack/request'
require 'rack/utils'
require 'rack/auth/abstract/handler'
require 'uri'
require 'openid' #gem
require 'openid/extension' #gem
require 'openid/store/memory' #gem

module Rack
  class Request
    def openid_request
      @env['rack.auth.openid.request']
    end

    def openid_response
      @env['rack.auth.openid.response']
    end
  end

  module Auth

    # Rack::Auth::OpenID provides a simple method for setting up an OpenID
    # Consumer. It requires the ruby-openid library from janrain to operate,
    # as well as a rack method of session management.
    #
    # The ruby-openid home page is at http://openidenabled.com/ruby-openid/.
    #
    # The OpenID specifications can be found at
    # http://openid.net/specs/openid-authentication-1_1.html
    # and
    # http://openid.net/specs/openid-authentication-2_0.html. Documentation
    # for published OpenID extensions and related topics can be found at
    # http://openid.net/developers/specs/.
    #
    # It is recommended to read through the OpenID spec, as well as
    # ruby-openid's documentation, to understand what exactly goes on. However
    # a setup as simple as the presented examples is enough to provide
    # Consumer functionality.
    #
    # This library strongly intends to utilize the OpenID 2.0 features of the
    # ruby-openid library, which provides OpenID 1.0 compatiblity.
    #
    # NOTE: Due to the amount of data that this library stores in the
    # session, Rack::Session::Cookie may fault.

    class OpenID

      class NoSession < RuntimeError; end
      class BadExtension < RuntimeError; end
      # Required for ruby-openid
      ValidStatus = [:success, :setup_needed, :cancel, :failure]

      # = Arguments
      #
      # The first argument is the realm, identifying the site they are trusting
      # with their identity. This is required, also treated as the trust_root
      # in OpenID 1.x exchanges.
      #
      # The optional second argument is a hash of options.
      #
      # == Options
      #
      # <tt>:return_to</tt> defines the url to return to after the client
      # authenticates with the openid service provider. This url should point
      # to where Rack::Auth::OpenID is mounted. If <tt>:return_to</tt> is not
      # provided, return_to will be the current url which allows flexibility
      # with caveats.
      #
      # <tt>:session_key</tt> defines the key to the session hash in the env.
      # It defaults to 'rack.session'.
      #
      # <tt>:openid_param</tt> defines at what key in the request parameters to
      # find the identifier to resolve. As per the 2.0 spec, the default is
      # 'openid_identifier'.
      #
      # <tt>:store</tt> defined what OpenID Store to use for persistant
      # information. By default a Store::Memory will be used.
      #
      # <tt>:immediate</tt> as true will make initial requests to be of an
      # immediate type. This is false by default. See OpenID specification
      # documentation.
      #
      # <tt>:extensions</tt> should be a hash of openid extension
      # implementations. The key should be the extension main module, the value
      # should be an array of arguments for extension::Request.new.
      # The hash is iterated over and passed to #add_extension for processing.
      # Please see #add_extension for further documentation.
      #
      # == Examples
      #
      #   simple_oid = OpenID.new('http://mysite.com/')
      #
      #   return_oid = OpenID.new('http://mysite.com/', {
      #     :return_to => 'http://mysite.com/openid'
      #   })
      #
      #   complex_oid = OpenID.new('http://mysite.com/',
      #     :immediate => true,
      #     :extensions => {
      #       ::OpenID::SReg => [['email'],['nickname']]
      #     }
      #   )
      #
      # = Advanced
      #
      # Most of the functionality of this library is encapsulated such that
      # expansion and overriding functions isn't difficult nor tricky.
      # Alternately, to avoid opening up singleton objects or subclassing, a
      # wrapper rack middleware can be composed to act upon Auth::OpenID's
      # responses. See #check and #finish for locations of pertinent data.
      #
      # == Responses
      #
      # To change the responses that Auth::OpenID returns, override the methods
      # #redirect, #bad_request, #unauthorized, #access_denied, and
      # #foreign_server_failure.
      #
      # Additionally #confirm_post_params is used when the URI would exceed
      # length limits on a GET request when doing the initial verification
      # request.
      #
      # == Processing
      #
      # To change methods of processing completed transactions, override the
      # methods #success, #setup_needed, #cancel, and #failure. Please ensure
      # the returned object is a rack compatible response.
      #
      # The first argument is an OpenID::Response, the second is a
      # Rack::Request of the current request, the last is the hash used in
      # ruby-openid handling, which can be found manually at
      # env['rack.session'][:openid].
      #
      # This is useful if you wanted to expand the processing done, such as
      # setting up user accounts.
      #
      #   oid_app = Rack::Auth::OpenID.new realm, :return_to => return_to
      #   def oid_app.success oid, request, session
      #     user = Models::User[oid.identity_url]
      #     user ||= Models::User.create_from_openid oid
      #     request['rack.session'][:user] = user.id
      #     redirect MyApp.site_home
      #   end
      #
      #   site_map['/openid'] = oid_app
      #   map = Rack::URLMap.new site_map
      #   ...

      def initialize(realm, options={})
        realm = URI(realm)
        raise ArgumentError, "Invalid realm: #{realm}" \
          unless realm.absolute? \
          and realm.fragment.nil? \
          and realm.scheme =~ /^https?$/ \
          and realm.host =~ /^(\*\.)?#{URI::REGEXP::PATTERN::URIC_NO_SLASH}+/
        realm.path = '/' if realm.path.empty?
        @realm = realm.to_s

        if ruri = options[:return_to]
          ruri = URI(ruri)
          raise ArgumentError, "Invalid return_to: #{ruri}" \
            unless ruri.absolute? \
            and ruri.scheme  =~ /^https?$/ \
            and ruri.fragment.nil?
          raise ArgumentError, "return_to #{ruri} not within realm #{realm}" \
            unless self.within_realm?(ruri)
          @return_to = ruri.to_s
        end

        @session_key  = options[:session_key]   || 'rack.session'
        @openid_param = options[:openid_param]  || 'openid_identifier'
        @store        = options[:store]         || ::OpenID::Store::Memory.new
        @immediate    = !!options[:immediate]

        @extensions = {}
        if extensions = options.delete(:extensions)
          extensions.each do |ext, args|
            add_extension ext, *args
          end
        end

        # Undocumented, semi-experimental
        @anonymous    = !!options[:anonymous]
      end

      attr_reader :realm, :return_to, :session_key, :openid_param, :store,
        :immediate, :extensions

      # Sets up and uses session data at <tt>:openid</tt> within the session.
      # Errors in this setup will raise a NoSession exception.
      #
      # If the parameter 'openid.mode' is set, which implies a followup from
      # the openid server, processing is passed to #finish and the result is
      # returned. However, if there is no appropriate openid information in the
      # session, a 400 error is returned.
      #
      # If the parameter specified by <tt>options[:openid_param]</tt> is
      # present, processing is passed to #check and the result is returned.
      #
      # If neither of these conditions are met, #unauthorized is called.

      def call(env)
        env['rack.auth.openid'] = self
        env_session = env[@session_key]
        unless env_session and env_session.is_a?(Hash)
          raise NoSession, 'No compatible session'
        end
        # let us work in our own namespace...
        session = (env_session[:openid] ||= {})
        unless session and session.is_a?(Hash)
          raise NoSession, 'Incompatible openid session'
        end

        request = Rack::Request.new(env)
        consumer = ::OpenID::Consumer.new(session, @store)

        if mode = request.GET['openid.mode']
          if session.key?(:openid_param)
            finish(consumer, session, request)
          else
            bad_request
          end
        elsif request.GET[@openid_param]
          check(consumer, session, request)
        else
          unauthorized
        end
      end

      # As the first part of OpenID consumer action, #check retrieves the data
      # required for completion.
      #
      # If all parameters fit within the max length of a URI, a 303 redirect
      # will be returned. Otherwise #confirm_post_params will be called.
      #
      # Any messages from OpenID's request are logged to env['rack.errors']
      #
      # <tt>env['rack.auth.openid.request']</tt> is the openid checkid request
      # instance.
      #
      # <tt>session[:openid_param]</tt> is set to the openid identifier
      # provided by the user.
      #
      # <tt>session[:return_to]</tt> is set to the return_to uri given to the
      # identity provider.

      def check(consumer, session, req)
        oid = consumer.begin(req.GET[@openid_param], @anonymous)
        req.env['rack.auth.openid.request'] = oid
        req.env['rack.errors'].puts(oid.message)
        p oid if $DEBUG

        ## Extension support
        extensions.each do |ext,args|
          oid.add_extension(ext::Request.new(*args))
        end

        session[:openid_param] = req.GET[openid_param]
        return_to_uri = return_to ? return_to : req.url
        session[:return_to] = return_to_uri
        immediate = session.key?(:setup_needed) ? false : immediate

        if oid.send_redirect?(realm, return_to_uri, immediate)
          uri = oid.redirect_url(realm, return_to_uri, immediate)
          redirect(uri)
        else
          confirm_post_params(oid, realm, return_to_uri, immediate)
        end
      rescue ::OpenID::DiscoveryFailure => e
        # thrown from inside OpenID::Consumer#begin by yadis stuff
        req.env['rack.errors'].puts([e.message, *e.backtrace]*"\n")
        return foreign_server_failure
      end

      # This is the final portion of authentication.
      # If successful, a redirect to the realm is be returned.
      # Data gathered from extensions are stored in session[:openid] with the
      # extension's namespace uri as the key.
      #
      # Any messages from OpenID's response are logged to env['rack.errors']
      #
      # <tt>env['rack.auth.openid.response']</tt> will contain the openid
      # response.

      def finish(consumer, session, req)
        oid = consumer.complete(req.GET, req.url)
        req.env['rack.auth.openid.response'] = oid
        req.env['rack.errors'].puts(oid.message)
        p oid if $DEBUG

        raise unless ValidStatus.include?(oid.status)
        __send__(oid.status, oid, req, session)
      end

      # The first argument should be the main extension module.
      # The extension module should contain the constants:
      #   * class Request, should have OpenID::Extension as an ancestor
      #   * class Response, should have OpenID::Extension as an ancestor
      #   * string NS_URI, which defining the namespace of the extension
      #
      # All trailing arguments will be passed to extension::Request.new in
      # #check.
      # The openid response will be passed to
      # extension::Response#from_success_response, #get_extension_args will be
      # called on the result to attain the gathered data.
      #
      # This method returns the key at which the response data will be found in
      # the session, which is the namespace uri by default.

      def add_extension(ext, *args)
        raise BadExtension unless valid_extension?(ext)
        extensions[ext] = args
        return ext::NS_URI
      end

      # Checks the validitity, in the context of usage, of a submitted
      # extension.

      def valid_extension?(ext)
        if not %w[NS_URI Request Response].all?{|c| ext.const_defined?(c) }
          raise ArgumentError, 'Extension is missing constants.'
        elsif not ext::Response.respond_to?(:from_success_response)
          raise ArgumentError, 'Response is missing required method.'
        end
        return true
      rescue
        return false
      end

      # Checks the provided uri to ensure it'd be considered within the realm.
      # is currently not compatible with wildcard realms.

      def within_realm? uri
        uri = URI.parse(uri.to_s)
        realm = URI.parse(self.realm)
        return false unless uri.absolute?
        return false unless uri.path[0, realm.path.size] == realm.path
        return false unless uri.host == realm.host or realm.host[/^\*\./]
        # for wildcard support, is awkward with URI limitations
        realm_match = Regexp.escape(realm.host).
          sub(/^\*\./,"^#{URI::REGEXP::PATTERN::URIC_NO_SLASH}+.")+'$'
        return false unless uri.host.match(realm_match)
        return true
      end
      alias_method :include?, :within_realm?

      protected

      ### These methods define some of the boilerplate responses.

      # Returns an html form page for posting to an Identity Provider if the
      # GET request would exceed the upper URI length limit.

      def confirm_post_params(oid, realm, return_to, immediate)
        Rack::Response.new.finish do |r|
          r.write '<html><head><title>Confirm...</title></head><body>'
          r.write oid.form_markup(realm, return_to, immediate)
          r.write '</body></html>'
        end
      end

      # Returns a 303 redirect with the destination of that provided by the
      # argument.

      def redirect(uri)
        [ 303, {'Content-Length'=>'0', 'Content-Type'=>'text/plain',
          'Location' => uri},
          [] ]
      end

      # Returns an empty 400 response.

      def bad_request
        [ 400, {'Content-Type'=>'text/plain', 'Content-Length'=>'0'},
          [''] ]
      end

      # Returns a basic unauthorized 401 response.

      def unauthorized
        [ 401, {'Content-Type' => 'text/plain', 'Content-Length' => '13'},
          ['Unauthorized.'] ]
      end

      # Returns a basic access denied 403 response.

      def access_denied
        [ 403, {'Content-Type' => 'text/plain', 'Content-Length' => '14'},
          ['Access denied.'] ]
      end

      # Returns a 503 response to be used if communication with the remote
      # OpenID server fails.

      def foreign_server_failure
        [ 503, {'Content-Type'=>'text/plain', 'Content-Length' => '23'},
          ['Foreign server failure.'] ]
      end

      private

      ### These methods are called after a transaction is completed, depending
      # on its outcome. These should all return a rack compatible response.
      # You'd want to override these to provide additional functionality.

      # Called to complete processing on a successful transaction.
      # Within the openid session, :openid_identity and :openid_identifier are
      # set to the user friendly and the standard representation of the
      # validated identity. All other data in the openid session is cleared.

      def success(oid, request, session)
        session.clear
        session[:openid_identity]   = oid.display_identifier
        session[:openid_identifier] = oid.identity_url
        extensions.keys.each do |ext|
          label     = ext.name[/[^:]+$/].downcase
          response  = ext::Response.from_success_response(oid)
          session[label] = response.data
        end
        redirect(realm)
      end

      # Called if the Identity Provider indicates further setup by the user is
      # required.
      # The identifier is retrived from the openid session at :openid_param.
      # And :setup_needed is set to true to prevent looping.

      def setup_needed(oid, request, session)
        identifier = session[:openid_param]
        session[:setup_needed] = true
        redirect req.script_name + '?' + openid_param + '=' + identifier
      end

      # Called if the user indicates they wish to cancel identification.
      # Data within openid session is cleared.

      def cancel(oid, request, session)
        session.clear
        access_denied
      end

      # Called if the Identity Provider indicates the user is unable to confirm
      # their identity. Data within the openid session is left alone, in case
      # of swarm auth attacks.

      def failure(oid, request, session)
        unauthorized
      end
    end

    # A class developed out of the request to use OpenID as an authentication
    # middleware. The request will be sent to the OpenID instance unless the
    # block evaluates to true. For example in rackup, you can use it as such:
    #
    #   use Rack::Session::Pool
    #   use Rack::Auth::OpenIDAuth, realm, openid_options do |env|
    #     env['rack.session'][:authkey] == a_string
    #   end
    #   run RackApp
    #
    # Or simply:
    #
    #   app = Rack::Auth::OpenIDAuth.new app, realm, openid_options, &auth

    class OpenIDAuth < Rack::Auth::AbstractHandler
      attr_reader :oid
      def initialize(app, realm, options={}, &auth)
        @oid = OpenID.new(realm, options)
        super(app, &auth)
      end

      def call(env)
        to = auth.call(env) ? @app : @oid
        to.call env
      end
    end
  end
end
