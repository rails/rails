require 'rack/utils'
require 'active_support/core_ext/uri'

module ActionDispatch
  class Static
    def initialize(app, root, cache_control=nil)
      @app           = app
      @root          = root.chomp('/')
      @compiled_root = /^#{Regexp.escape(@root)}/
      @file_server   = ::Rack::File.new(@root, cache_control)
    end

    def match?(path)
      path = path.dup

      full_path = path.empty? ? @root : File.join(@root, escape_glob_chars(unescape_path(path)))
      paths = "#{full_path}#{ext}"

      matches = Dir[paths]
      match = matches.detect { |m| File.file?(m) }
      if match
        match.sub!(@compiled_root, '')
        ::Rack::Utils.escape(match)
      end
    end

    def call(env)
      case env['REQUEST_METHOD']
      when 'GET', 'HEAD'
        path = env['PATH_INFO'].chomp('/')
        if match = match?(path)
          env["PATH_INFO"] = match
          return @file_server.call(env)
        end
      end

      @app.call(env)
    end

    def ext
      @ext ||= begin
        ext = ::ActionController::Base.default_static_extension
        "{,#{ext},/index#{ext}}"
      end
    end

    def unescape_path(path)
      URI.parser.unescape(path)
    end

    def escape_glob_chars(path)
      path.force_encoding('binary') if path.respond_to? :force_encoding
      path.gsub(/[*?{}\[\]]/, "\\\\\\&")
    end
  end
end
