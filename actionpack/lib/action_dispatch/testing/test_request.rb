require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/hash/reverse_merge'
require 'rack/utils'

module ActionDispatch
  class TestRequest < Request
    DEFAULT_ENV = Rack::MockRequest.env_for('/')

    def self.new(env = {})
      super
    end

    def initialize(env = {})
      env = Rails.application.env_config.merge(env) if defined?(Rails.application)
      super(DEFAULT_ENV.merge(env))

      @cookies = nil
      self.host        = 'test.host'
      self.remote_addr = '0.0.0.0'
      self.user_agent  = 'Rails Testing'
    end

    def env
      write_cookies!
      delete_nil_values!
      super
    end

    def request_method=(method)
      @env['REQUEST_METHOD'] = method.to_s.upcase
    end

    def host=(host)
      @env['HTTP_HOST'] = host
    end

    def port=(number)
      @env['SERVER_PORT'] = number.to_i
    end

    def request_uri=(uri)
      @env['REQUEST_URI'] = uri
    end

    def path=(path)
      @env['PATH_INFO'] = path
    end

    def action=(action_name)
      path_parameters["action"] = action_name.to_s
    end

    def if_modified_since=(last_modified)
      @env['HTTP_IF_MODIFIED_SINCE'] = last_modified
    end

    def if_none_match=(etag)
      @env['HTTP_IF_NONE_MATCH'] = etag
    end

    def remote_addr=(addr)
      @env['REMOTE_ADDR'] = addr
    end

    def user_agent=(user_agent)
      @env['HTTP_USER_AGENT'] = user_agent
    end

    def accept=(mime_types)
      @env.delete('action_dispatch.request.accepts')
      @env['HTTP_ACCEPT'] = Array(mime_types).collect { |mime_type| mime_type.to_s }.join(",")
    end

    def cookies
      @cookies ||= super
    end

    private
      def write_cookies!
        unless @cookies.blank?
          @env['HTTP_COOKIE'] = @cookies.map { |name, value| escape_cookie(name, value) }.join('; ')
        end
      end

      def escape_cookie(name, value)
        "#{Rack::Utils.escape(name)}=#{Rack::Utils.escape(value.to_s)}"
      end

      def delete_nil_values!
        @env.delete_if { |k, v| v.nil? }
      end
  end
end
