# AUTHOR: blink <blinketje@gmail.com>; blink#ruby-lang@irc.freenode.net

gem 'ruby-openid', '~> 2' if defined? Gem
require 'rack/auth/abstract/handler' #rack
require 'uri' #std
require 'pp' #std
require 'openid' #gem
require 'openid/extension' #gem
require 'openid/store/memory' #gem

module Rack
  module Auth
    # Rack::Auth::OpenID provides a simple method for permitting
    # openid based logins. It requires the ruby-openid library from
    # janrain to operate, as well as a rack method of session management.
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
    # functionality.
    #
    # This library strongly intends to utilize the OpenID 2.0 features of the
    # ruby-openid library, while maintaining OpenID 1.0 compatiblity.
    #
    # All responses from this rack application will be 303 redirects unless an
    # error occurs, with the exception of an authentication request requiring
    # an HTML form submission.
    #
    # NOTE: Extensions are not currently supported by this implimentation of
    # the OpenID rack application due to the complexity of the current
    # ruby-openid extension handling.
    #
    # NOTE: Due to the amount of data that this library stores in the
    # session, Rack::Session::Cookie may fault.
    class OpenID < AbstractHandler
      class NoSession < RuntimeError; end
      # Required for ruby-openid
      OIDStore = ::OpenID::Store::Memory.new
      HTML = '<html><head><title>%s</title></head><body>%s</body></html>'

      # A Hash of options is taken as it's single initializing
      # argument. For example:
      #
      #   simple_oid = OpenID.new('http://mysite.com/')
      #
      #   return_oid = OpenID.new('http://mysite.com/', {
      #     :return_to => 'http://mysite.com/openid'
      #   })
      #
      #   page_oid = OpenID.new('http://mysite.com/',
      #     :login_good => 'http://mysite.com/auth_good'
      #   )
      #
      #   complex_oid = OpenID.new('http://mysite.com/',
      #     :return_to => 'http://mysite.com/openid',
      #     :login_good => 'http://mysite.com/user/preferences',
      #     :auth_fail => [500, {'Content-Type'=>'text/plain'},
      #       'Unable to negotiate with foreign server.'],
      #     :immediate => true,
      #     :extensions => {
      #       ::OpenID::SReg => [['email'],['nickname']]
      #     }
      #   )
      #
      # = Arguments
      #
      # The first argument is the realm, identifying the site they are trusting
      # with their identity. This is required.
      #
      # NOTE: In OpenID 1.x, the realm or trust_root is optional and the
      # return_to url is required. As this library strives tward ruby-openid
      # 2.0, and OpenID 2.0 compatibiliy, the realm is required and return_to
      # is optional. However, this implimentation is still backwards compatible
      # with OpenID 1.0 servers.
      #
      # The optional second argument is a hash of options.
      #
      # == Options
      #
      # <tt>:return_to</tt> defines the url to return to after the client
      # authenticates with the openid service provider. This url should point
      # to where Rack::Auth::OpenID is mounted. If <tt>:return_to</tt> is not
      # provided, :return_to will be the current url including all query
      # parameters.
      #
      # <tt>:session_key</tt> defines the key to the session hash in the env.
      # It defaults to 'rack.session'.
      #
      # <tt>:openid_param</tt> defines at what key in the request parameters to
      # find the identifier to resolve. As per the 2.0 spec, the default is
      # 'openid_identifier'.
      #
      # <tt>:immediate</tt> as true will make immediate type of requests the
      # default. See OpenID specification documentation.
      #
      # === URL options
      #
      # <tt>:login_good</tt> is the url to go to after the authentication
      # process has completed.
      #
      # <tt>:login_fail</tt> is the url to go to after the authentication
      # process has failed.
      #
      # <tt>:login_quit</tt> is the url to go to after the authentication
      # process
      # has been cancelled.
      #
      # === Response options
      #
      # <tt>:no_session</tt> should be a rack response to be returned if no or
      # an incompatible session is found.
      #
      # <tt>:auth_fail</tt> should be a rack response to be returned if an
      # OpenID::DiscoveryFailure occurs. This is typically due to being unable
      # to access the identity url or identity server.
      #
      # <tt>:error</tt> should be a rack response to return if any other
      # generic error would occur and <tt>options[:catch_errors]</tt> is true.
      #
      # === Extensions
      #
      # <tt>:extensions</tt> should be a hash of openid extension
      # implementations. The key should be the extension main module, the value
      # should be an array of arguments for extension::Request.new
      #
      # The hash is iterated over and passed to #add_extension for processing.
      # Please see #add_extension for further documentation.
      def initialize(realm, options={})
        @realm = realm
        realm = URI(realm)
        if realm.path.empty?
          raise ArgumentError, "Invalid realm path: '#{realm.path}'"
        elsif not realm.absolute?
          raise ArgumentError, "Realm '#{@realm}' not absolute"
        end

        [:return_to, :login_good, :login_fail, :login_quit].each do |key|
          if options.key? key and luri = URI(options[key])
            if !luri.absolute?
              raise ArgumentError, ":#{key} is not an absolute uri: '#{luri}'"
            end
          end
        end

        if options[:return_to] and ruri = URI(options[:return_to])
          if ruri.path.empty?
            raise ArgumentError, "Invalid return_to path: '#{ruri.path}'"
          elsif realm.path != ruri.path[0, realm.path.size]
            raise ArgumentError, 'return_to not within realm.' \
          end
        end

        # TODO: extension support
        if extensions = options.delete(:extensions)
          extensions.each do |ext, args|
            add_extension ext, *args
          end
        end

        @options = {
          :session_key => 'rack.session',
          :openid_param => 'openid_identifier',
          #:return_to, :login_good, :login_fail, :login_quit
          #:no_session, :auth_fail, :error
          :store => OIDStore,
          :immediate => false,
          :anonymous => false,
          :catch_errors => false
        }.merge(options)
        @extensions = {}
      end

      attr_reader :options, :extensions

      # It sets up and uses session data at <tt>:openid</tt> within the
      # session. It sets up the ::OpenID::Consumer using the store specified by
      # <tt>options[:store]</tt>.
      #
      # If the parameter specified by <tt>options[:openid_param]</tt> is
      # present, processing is passed to #check and the result is returned.
      #
      # If the parameter 'openid.mode' is set, implying a followup from the
      # openid server, processing is passed to #finish and the result is
      # returned.
      #
      # If neither of these conditions are met, a 400 error is returned.
      #
      # If an error is thrown and <tt>options[:catch_errors]</tt> is false, the
      # exception will be reraised. Otherwise a 500 error is returned.
      def call(env)
        env['rack.auth.openid'] = self
        session = env[@options[:session_key]]
        unless session and session.is_a? Hash
          raise(NoSession, 'No compatible session')
        end
        # let us work in our own namespace...
        session = (session[:openid] ||= {})
        unless session and session.is_a? Hash
          raise(NoSession, 'Incompatible session')
        end

        request = Rack::Request.new env
        consumer = ::OpenID::Consumer.new session, @options[:store]

        if request.params['openid.mode']
          finish consumer, session, request
        elsif request.params[@options[:openid_param]]
          check consumer, session, request
        else
          env['rack.errors'].puts "No valid params provided."
          bad_request
        end
      rescue NoSession
        env['rack.errors'].puts($!.message, *$@)

        @options. ### Missing or incompatible session
          fetch :no_session, [ 500,
            {'Content-Type'=>'text/plain'},
            $!.message ]
      rescue
        env['rack.errors'].puts($!.message, *$@)

        if not @options[:catch_error]
          raise($!)
        end
        @options.
          fetch :error, [ 500,
            {'Content-Type'=>'text/plain'},
            'OpenID has encountered an error.' ]
      end

      # As the first part of OpenID consumer action, #check retrieves the data
      # required for completion.
      #
      # * <tt>session[:openid][:openid_param]</tt> is set to the submitted
      #   identifier to be authenticated.
      # * <tt>session[:openid][:site_return]</tt> is set as the request's
      #   HTTP_REFERER, unless already set.
      # * <tt>env['rack.auth.openid.request']</tt> is the openid checkid
      #   request instance.
      def check(consumer, session, req)
        session[:openid_param]  = req.params[@options[:openid_param]]
        oid = consumer.begin(session[:openid_param], @options[:anonymous])
        pp oid if $DEBUG
        req.env['rack.auth.openid.request'] = oid

        session[:site_return] ||= req.env['HTTP_REFERER']

        # SETUP_NEEDED check!
        # see OpenID::Consumer::CheckIDRequest docs
        query_args = [@realm, *@options.values_at(:return_to, :immediate)]
        query_args[1] ||= req.url
        query_args[2] = false if session.key? :setup_needed
        pp query_args if $DEBUG

        ## Extension support
        extensions.each do |ext,args|
          oid.add_extension ext::Request.new(*args)
        end

        if oid.send_redirect?(*query_args)
          redirect = oid.redirect_url(*query_args)
          if $DEBUG
            pp redirect
            pp Rack::Utils.parse_query(URI(redirect).query)
          end
          [ 303, {'Location'=>redirect}, [] ]
        else
          # check on 'action' option.
          formbody = oid.form_markup(*query_args)
          if $DEBUG
            pp formbody
          end
          body = HTML % ['Confirm...', formbody]
          [ 200, {'Content-Type'=>'text/html'}, body.to_a ]
        end
      rescue ::OpenID::DiscoveryFailure => e
        # thrown from inside OpenID::Consumer#begin by yadis stuff
        req.env['rack.errors'].puts($!.message, *$@)

        @options. ### Foreign server failed
          fetch :auth_fail, [ 503,
            {'Content-Type'=>'text/plain'},
            'Foreign server failure.' ]
      end

      # This is the final portion of authentication. Unless any errors outside
      # of specification occur, a 303 redirect will be returned with Location
      # determined by the OpenID response type. If none of the response type
      # :login_* urls are set, the redirect will be set to
      # <tt>session[:openid][:site_return]</tt>. If
      # <tt>session[:openid][:site_return]</tt> is unset, the realm will be
      # used.
      #
      # Any messages from OpenID's response are appended to the 303 response
      # body.
      #
      # Data gathered from extensions are stored in session[:openid] with the
      # extension's namespace uri as the key.
      #
      # * <tt>env['rack.auth.openid.response']</tt> is the openid response.
      #
      # The four valid possible outcomes are:
      # * failure: <tt>options[:login_fail]</tt> or
      #   <tt>session[:site_return]</tt> or the realm
      #   * <tt>session[:openid]</tt> is cleared and any messages are send to
      #     rack.errors
      #   * <tt>session[:openid]['authenticated']</tt> is <tt>false</tt>
      # * success: <tt>options[:login_good]</tt> or
      #   <tt>session[:site_return]</tt> or the realm
      #   * <tt>session[:openid]</tt> is cleared
      #   * <tt>session[:openid]['authenticated']</tt> is <tt>true</tt>
      #   * <tt>session[:openid]['identity']</tt> is the actual identifier
      #   * <tt>session[:openid]['identifier']</tt> is the pretty identifier
      # * cancel: <tt>options[:login_good]</tt> or
      #   <tt>session[:site_return]</tt> or the realm
      #   * <tt>session[:openid]</tt> is cleared
      #   * <tt>session[:openid]['authenticated']</tt> is <tt>false</tt>
      # * setup_needed: resubmits the authentication request. A flag is set for
      #   non-immediate handling.
      #   * <tt>session[:openid][:setup_needed]</tt> is set to <tt>true</tt>,
      #     which will prevent immediate style openid authentication.
      def finish(consumer, session, req)
        oid = consumer.complete(req.params, req.url)
        pp oid if $DEBUG
        req.env['rack.auth.openid.response'] = oid

        goto = session.fetch :site_return, @realm
        body = []

        case oid.status
        when ::OpenID::Consumer::FAILURE
          session.clear
          session['authenticated'] = false
          req.env['rack.errors'].puts oid.message

          goto = @options[:login_fail] if @option.key? :login_fail
          body << "Authentication unsuccessful.\n"
        when ::OpenID::Consumer::SUCCESS
          session.clear

          ## Extension support
          extensions.each do |ext, args|
            session[ext::NS_URI] = ext::Response.
              from_success_response(oid).
              get_extension_args
          end

          session['authenticated'] = true
          # Value for unique identification and such
          session['identity'] = oid.identity_url
          # Value for display and UI labels
          session['identifier'] = oid.display_identifier

          goto = @options[:login_good] if @options.key? :login_good
          body << "Authentication successful.\n"
        when ::OpenID::Consumer::CANCEL
          session.clear
          session['authenticated'] = false

          goto = @options[:login_fail] if @option.key? :login_fail
          body << "Authentication cancelled.\n"
        when ::OpenID::Consumer::SETUP_NEEDED
          session[:setup_needed] = true
          unless o_id = session[:openid_param]
            raise('Required values missing.')
          end

          goto = req.script_name+
            '?'+@options[:openid_param]+
            '='+o_id
          body << "Reauthentication required.\n"
        end
        body << oid.message if oid.message
        [ 303, {'Location'=>goto}, body]
      end

      # The first argument should be the main extension module.
      # The extension module should contain the constants:
      #   * class Request, with OpenID::Extension as an ancestor
      #   * class Response, with OpenID::Extension as an ancestor
      #   * string NS_URI, which defines the namespace of the extension, should
      #     be an absolute http uri
      #
      # All trailing arguments will be passed to extension::Request.new in
      # #check.
      # The openid response will be passed to
      # extension::Response#from_success_response, #get_extension_args will be
      # called on the result to attain the gathered data.
      #
      # This method returns the key at which the response data will be found in
      # the session, which is the namespace uri by default.
      def add_extension ext, *args
        if not ext.is_a? Module
          raise TypeError, "#{ext.inspect} is not a module"
        elsif not (m = %w'Request Response NS_URI' - ext.constants).empty?
          raise ArgumentError, "#{ext.inspect} missing #{m*', '}"
        end

        consts = [ext::Request, ext::Response]

        if not consts.all?{|c| c.is_a? Class }
          raise TypeError, "#{ext.inspect}'s Request or Response is not a class"
        elsif not consts.all?{|c| ::OpenID::Extension > c }
          raise ArgumentError, "#{ext.inspect}'s Request or Response not a decendant of OpenID::Extension"
        end

        if not ext::NS_URI.is_a? String
          raise TypeError, "#{ext.inspect}'s NS_URI is not a string"
        elsif not uri = URI(ext::NS_URI)
          raise ArgumentError, "#{ext.inspect}'s NS_URI is not a valid uri"
        elsif not uri.scheme =~ /^https?$/
          raise ArgumentError, "#{ext.inspect}'s NS_URI is not an http uri"
        elsif not uri.absolute?
          raise ArgumentError, "#{ext.inspect}'s NS_URI is not and absolute uri"
        end
        @extensions[ext] = args
        return ext::NS_URI
      end

      # A conveniance method that returns the namespace of all current
      # extensions used by this instance.
      def extension_namespaces
        @extensions.keys.map{|e|e::NS_URI}
      end
    end
  end
end
