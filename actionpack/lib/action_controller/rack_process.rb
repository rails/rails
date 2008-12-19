require 'action_controller/cgi_ext'

module ActionController #:nodoc:
  class RackRequest < AbstractRequest #:nodoc:
    attr_accessor :session_options

    class SessionFixationAttempt < StandardError #:nodoc:
    end

    def initialize(env)
      @env = env
      super()
    end

    %w[ AUTH_TYPE GATEWAY_INTERFACE PATH_INFO
        PATH_TRANSLATED REMOTE_HOST
        REMOTE_IDENT REMOTE_USER SCRIPT_NAME
        SERVER_NAME SERVER_PROTOCOL

        HTTP_ACCEPT HTTP_ACCEPT_CHARSET HTTP_ACCEPT_ENCODING
        HTTP_ACCEPT_LANGUAGE HTTP_CACHE_CONTROL HTTP_FROM
        HTTP_NEGOTIATE HTTP_PRAGMA HTTP_REFERER HTTP_USER_AGENT ].each do |env|
      define_method(env.sub(/^HTTP_/n, '').downcase) do
        @env[env]
      end
    end

    def query_string
      qs = super
      if !qs.blank?
        qs
      else
        @env['QUERY_STRING']
      end
    end

    def body_stream #:nodoc:
      @env['rack.input']
    end

    def key?(key)
      @env.key?(key)
    end

    def cookies
      Rack::Request.new(@env).cookies
    end

    def server_port
      @env['SERVER_PORT'].to_i
    end

    def server_software
      @env['SERVER_SOFTWARE'].split("/").first
    end

    def session_options
      @env['rack.session.options'] ||= {}
    end

    def session_options=(options)
      @env['rack.session.options'] = options
    end

    def session
      @env['rack.session'] ||= {}
    end

    def reset_session
      @env['rack.session'] = {}
    end
  end
end
