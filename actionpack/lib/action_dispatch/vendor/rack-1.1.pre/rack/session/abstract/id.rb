# AUTHOR: blink <blinketje@gmail.com>; blink#ruby-lang@irc.freenode.net
# bugrep: Andreas Zehnder

require 'time'
require 'rack/request'
require 'rack/response'

module Rack

  module Session

    module Abstract

      # ID sets up a basic framework for implementing an id based sessioning
      # service. Cookies sent to the client for maintaining sessions will only
      # contain an id reference. Only #get_session and #set_session are
      # required to be overwritten.
      #
      # All parameters are optional.
      # * :key determines the name of the cookie, by default it is
      #   'rack.session'
      # * :path, :domain, :expire_after, :secure, and :httponly set the related
      #   cookie options as by Rack::Response#add_cookie
      # * :defer will not set a cookie in the response.
      # * :renew (implementation dependent) will prompt the generation of a new
      #   session id, and migration of data to be referenced at the new id. If
      #   :defer is set, it will be overridden and the cookie will be set.
      # * :sidbits sets the number of bits in length that a generated session
      #   id will be.
      #
      # These options can be set on a per request basis, at the location of
      # env['rack.session.options']. Additionally the id of the session can be
      # found within the options hash at the key :id. It is highly not
      # recommended to change its value.
      #
      # Is Rack::Utils::Context compatible.

      class ID
        DEFAULT_OPTIONS = {
          :path =>          '/',
          :domain =>        nil,
          :expire_after =>  nil,
          :secure =>        false,
          :httponly =>      true,
          :defer =>         false,
          :renew =>         false,
          :sidbits =>       128
        }

        attr_reader :key, :default_options
        def initialize(app, options={})
          @app = app
          @key = options[:key] || "rack.session"
          @default_options = self.class::DEFAULT_OPTIONS.merge(options)
        end

        def call(env)
          context(env)
        end

        def context(env, app=@app)
          load_session(env)
          status, headers, body = app.call(env)
          commit_session(env, status, headers, body)
        end

        private

        # Generate a new session id using Ruby #rand.  The size of the
        # session id is controlled by the :sidbits option.
        # Monkey patch this to use custom methods for session id generation.

        def generate_sid
          "%0#{@default_options[:sidbits] / 4}x" %
            rand(2**@default_options[:sidbits] - 1)
        end

        # Extracts the session id from provided cookies and passes it and the
        # environment to #get_session. It then sets the resulting session into
        # 'rack.session', and places options and session metadata into
        # 'rack.session.options'.

        def load_session(env)
          request = Rack::Request.new(env)
          session_id = request.cookies[@key]

          begin
            session_id, session = get_session(env, session_id)
            env['rack.session'] = session
          rescue
            env['rack.session'] = Hash.new
          end

          env['rack.session.options'] = @default_options.
            merge(:id => session_id)
        end

        # Acquires the session from the environment and the session id from
        # the session options and passes them to #set_session. If successful
        # and the :defer option is not true, a cookie will be added to the
        # response with the session's id.

        def commit_session(env, status, headers, body)
          session = env['rack.session']
          options = env['rack.session.options']
          session_id = options[:id]

          if not session_id = set_session(env, session_id, session, options)
            env["rack.errors"].puts("Warning! #{self.class.name} failed to save session. Content dropped.")
            [status, headers, body]
          elsif options[:defer] and not options[:renew]
            env["rack.errors"].puts("Defering cookie for #{session_id}") if $VERBOSE
            [status, headers, body]
          else
            cookie = Hash.new
            cookie[:value] = session_id
            cookie[:expires] = Time.now + options[:expire_after] unless options[:expire_after].nil?
            response = Rack::Response.new(body, status, headers)
            response.set_cookie(@key, cookie.merge(options))
            response.to_a
          end
        end

        # All thread safety and session retrival proceedures should occur here.
        # Should return [session_id, session].
        # If nil is provided as the session id, generation of a new valid id
        # should occur within.

        def get_session(env, sid)
          raise '#get_session not implemented.'
        end

        # All thread safety and session storage proceedures should occur here.
        # Should return true or false dependant on whether or not the session
        # was saved or not.
        def set_session(env, sid, session, options)
          raise '#set_session not implemented.'
        end
      end
    end
  end
end
