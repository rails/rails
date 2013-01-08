require 'rack/utils'
require 'rack/mime'
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

      Dir[paths].detect { |m| File.file?(m) }
    end

    def call(env)
      case env['REQUEST_METHOD']
      when 'GET', 'HEAD'
        path = env['PATH_INFO'].chomp('/')
        if filename = match?(path)
          compressed_filename = "#{filename}.gz"
          compressed_exists = File.file?(compressed_filename)

          wants_compressed = !!(env['HTTP_ACCEPT_ENCODING'] =~ /\bgzip\b/)

          if wants_compressed && compressed_exists
            path = compressed_filename
          else
            path = filename
          end

          path.sub!(@compiled_root, '')
          env["PATH_INFO"] = ::Rack::Utils.escape(path)
          status, headers, body = @file_server.call(env)

          if compressed_exists
            headers['Vary'] = 'Accept-Encoding'

            if wants_compressed
              headers['Content-Encoding'] = 'gzip'
              # Rack::File will always return 'application/gzip', so we need
              # to set the correct mime header here
              headers['Content-Type'] = Rack::Mime.mime_type(
                  ::File.extname(filename), 'text/plain')
            end
          end

          return [status, headers, body]
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
