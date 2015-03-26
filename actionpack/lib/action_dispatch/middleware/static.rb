require 'rack/utils'
require 'active_support/core_ext/uri'

module ActionDispatch
  # This middleware returns a file's contents from disk in the body response.
  # When initialized it can accept an optional 'Cache-Control' header which
  # will be set when a response containing a file's contents is delivered.
  #
  # This middleware will render the file specified in `env["PATH_INFO"]`
  # where the base path is in the +root+ directory. For example if the +root+
  # is set to `public/` then a request with `env["PATH_INFO"]` of
  # `assets/application.js` will return a response with contents of a file
  # located at `public/assets/application.js` if the file exists. If the file
  # does not exist a 404 "File not Found" response will be returned.
  class FileHandler
    def initialize(root, cache_control)
      @root          = root.chomp('/')
      @compiled_root = /^#{Regexp.escape(root)}/
      headers        = cache_control && { 'Cache-Control' => cache_control }
      @file_server = ::Rack::File.new(@root, headers)
    end

    def match?(path)
      path = URI.parser.unescape(path)
      return false unless path.valid_encoding?

      paths = [path, "#{path}#{ext}", "#{path}/index#{ext}"].map { |v|
        Rack::Utils.clean_path_info v
      }

      if match = paths.detect { |p|
        path = File.join(@root, p.force_encoding('UTF-8'))
        begin
          File.file?(path) && File.readable?(path)
        rescue SystemCallError
          false
        end

      }
        return ::Rack::Utils.escape(match)
      end
    end

    def call(env)
      path      = env['PATH_INFO']
      gzip_path = gzip_file_path(path)

      if gzip_path && gzip_encoding_accepted?(env)
        env['PATH_INFO']            = gzip_path
        status, headers, body       = @file_server.call(env)
        if status == 304
          return [status, headers, body]
        end
        headers['Content-Encoding'] = 'gzip'
        headers['Content-Type']     = content_type(path)
      else
        status, headers, body = @file_server.call(env)
      end

      headers['Vary'] = 'Accept-Encoding' if gzip_path

      return [status, headers, body]
    ensure
      env['PATH_INFO'] = path
    end

    private
      def ext
        ::ActionController::Base.default_static_extension
      end

      def content_type(path)
        ::Rack::Mime.mime_type(::File.extname(path), 'text/plain')
      end

      def gzip_encoding_accepted?(env)
        env['HTTP_ACCEPT_ENCODING'] =~ /\bgzip\b/i
      end

      def gzip_file_path(path)
        can_gzip_mime = content_type(path) =~ /\A(?:text\/|application\/javascript)/
        gzip_path     = "#{path}.gz"
        if can_gzip_mime && File.exist?(File.join(@root, ::Rack::Utils.unescape(gzip_path)))
          gzip_path
        else
          false
        end
      end
  end

  # This middleware will attempt to return the contents of a file's body from
  # disk in the response.  If a file is not found on disk, the request will be
  # delegated to the application stack. This middleware is commonly initialized
  # to serve assets from a server's `public/` directory.
  #
  # This middleware verifies the path to ensure that only files
  # living in the root directory can be rendered. A request cannot
  # produce a directory traversal using this middleware. Only 'GET' and 'HEAD'
  # requests will result in a file being returned.
  class Static
    def initialize(app, path, cache_control=nil)
      @app = app
      @file_handler = FileHandler.new(path, cache_control)
    end

    def call(env)
      case env['REQUEST_METHOD']
      when 'GET', 'HEAD'
        path = env['PATH_INFO'].chomp('/')
        if match = @file_handler.match?(path)
          env["PATH_INFO"] = match
          return @file_handler.call(env)
        end
      end

      @app.call(env)
    end
  end
end
