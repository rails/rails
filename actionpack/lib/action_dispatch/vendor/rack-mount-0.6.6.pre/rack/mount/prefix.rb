require 'rack/mount/utils'

module Rack::Mount
  class Prefix #:nodoc:
    EMPTY_STRING = ''.freeze
    PATH_INFO    = 'PATH_INFO'.freeze
    SCRIPT_NAME  = 'SCRIPT_NAME'.freeze
    SLASH        = '/'.freeze

    KEY = 'rack.mount.prefix'.freeze

    def initialize(app, prefix = nil)
      @app, @prefix = app, prefix.freeze
      freeze
    end

    def call(env)
      if prefix = env[KEY] || @prefix
        old_path_info = env[PATH_INFO].dup
        old_script_name = env[SCRIPT_NAME].dup

        begin
          env[PATH_INFO] = Utils.normalize_path(env[PATH_INFO].sub(prefix, EMPTY_STRING))
          env[PATH_INFO] = EMPTY_STRING if env[PATH_INFO] == SLASH
          env[SCRIPT_NAME] = Utils.normalize_path(env[SCRIPT_NAME].to_s + prefix)
          @app.call(env)
        ensure
          env[PATH_INFO] = old_path_info
          env[SCRIPT_NAME] = old_script_name
        end
      else
        @app.call(env)
      end
    end
  end
end
