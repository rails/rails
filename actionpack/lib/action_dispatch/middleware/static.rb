# frozen_string_literal: true

require "rack/utils"
require "active_support/core_ext/uri"

module ActionDispatch
  # This middleware returns a file's contents from disk in the body response.
  # When initialized, it can accept optional HTTP headers, which will be set
  # when a response containing a file's contents is delivered.
  #
  # This middleware will render the file specified in <tt>env["PATH_INFO"]</tt>
  # where the base path is in the +root+ directory. For example, if the +root+
  # is set to +public/+, then a request with <tt>env["PATH_INFO"]</tt> of
  # +assets/application.js+ will return a response with the contents of a file
  # located at +public/assets/application.js+ if the file exists. If the file
  # does not exist, a 404 "File not Found" response will be returned.
  class FileHandler
    def initialize(root, index: "index", headers: {})
      @root          = root.chomp("/").b
      @file_server   = ::Rack::File.new(@root, headers)
      @index         = index
    end

    # Takes a path to a file. If the file is found, has valid encoding, and has
    # correct read permissions, the return value is a URI-escaped string
    # representing the filename. Otherwise, false is returned.
    #
    # Used by the +Static+ class to check the existence of a valid file
    # in the server's +public/+ directory (see Static#call).
    def match?(path)
      path = ::Rack::Utils.unescape_path path
      return false unless ::Rack::Utils.valid_path? path
      path = ::Rack::Utils.clean_path_info path

      paths = [path, "#{path}#{ext}", "#{path}/#{@index}#{ext}"]

      if match = paths.detect { |p|
        path = File.join(@root, p.b)
        begin
          File.file?(path) && File.readable?(path)
        rescue SystemCallError
          false
        end
      }
        ::Rack::Utils.escape_path(match).b
      end
    end

    def call(env)
      serve(Rack::Request.new(env))
    end

    def serve(request)
      path      = request.path_info
      gzip_path = gzip_file_path(path)

      if gzip_path && gzip_encoding_accepted?(request)
        request.path_info           = gzip_path
        status, headers, body       = @file_server.call(request.env)
        if status == 304
          return [status, headers, body]
        end
        headers["Content-Encoding"] = "gzip"
        headers["Content-Type"]     = content_type(path)
      else
        status, headers, body = @file_server.call(request.env)
      end

      headers["Vary"] = "Accept-Encoding" if gzip_path

      [status, headers, body]
    ensure
      request.path_info = path
    end

    private
      def ext
        ::ActionController::Base.default_static_extension
      end

      def content_type(path)
        ::Rack::Mime.mime_type(::File.extname(path), "text/plain")
      end

      def gzip_encoding_accepted?(request)
        request.accept_encoding.any? { |enc, quality| enc =~ /\bgzip\b/i }
      end

      def gzip_file_path(path)
        can_gzip_mime = content_type(path) =~ /\A(?:text\/|application\/javascript)/
        gzip_path     = "#{path}.gz"
        if can_gzip_mime && File.exist?(File.join(@root, ::Rack::Utils.unescape_path(gzip_path)))
          gzip_path
        else
          false
        end
      end
  end

  # This middleware will attempt to return the contents of a file's body from
  # disk in the response. If a file is not found on disk, the request will be
  # delegated to the application stack. This middleware is commonly initialized
  # to serve assets from a server's +public/+ directory.
  #
  # This middleware verifies the path to ensure that only files
  # living in the root directory can be rendered. A request cannot
  # produce a directory traversal using this middleware. Only 'GET' and 'HEAD'
  # requests will result in a file being returned.
  class Static
    def initialize(app, path, index: "index", headers: {})
      @app = app
      @file_handler = FileHandler.new(path, index: index, headers: headers)
    end

    def call(env)
      req = Rack::Request.new env

      if req.get? || req.head?
        path = req.path_info.chomp("/")
        if match = @file_handler.match?(path)
          req.path_info = match
          return @file_handler.serve(req)
        end
      end

      @app.call(req.env)
    end
  end
end
