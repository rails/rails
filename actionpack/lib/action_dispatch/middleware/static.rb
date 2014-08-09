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
    # Initializes a middleware capable of serving a static file. The +root+ is
    # the path to the directory where static files are stored. The +options+:
    #
    # == Options:
    # * <tt>:headers</tt> - A hash containing header key values that will be returned when assets are served
    # * <tt>:cache_asset_lookup</tt> - When set to true the disk will not be accessed every time `match?` is called
    #
    # == Example:
    #
    #  FileHandler.new(Rails.root.join("public"), headers: { 'Cache-Control' => "public, max-age=2592000"})
    def initialize(root, options_or_deprecated_cache_control)
      if options_or_deprecated_cache_control.is_a?(Hash)
        options = options_or_deprecated_cache_control
      else
        cache_control = options_or_deprecated_cache_control
        options       = { headers: { 'Cache-Control' => cache_control } }
        ActiveSupport::Deprecation.warn <<-MSG.strip_heredoc
          #{self.class} will no longer accept a `cache_control` argument in Rails 5.
          Switch to the `headers` keyword argument: `headers: { 'Cache-Control' => #{cache_control.inspect} }`
        MSG
      end
      @root = root.chomp('/')
      @base_hash = false
      @base_hash = parse_root if options[:cache_asset_lookup]
      @file_server = ::Rack::File.new(@root, options[:headers])
    end

    # This method returns true if the supplied +path+
    # originates from a directory in the root or if the +path+
    # contains a file in the root directory.
    #
    # This is an optimization for speed so that requests to paths that
    # cannot possibly exist on the disk will not hit the file system.
    #
    # This functionality can be disabled by passing in the
    # option: `cache_asset_lookup: false` on initilization
    def base_of_path_exists_in_root_directory?(path)
      return true unless @base_hash
      @base_hash[path.split(File::SEPARATOR)[1]]
    end

    def match?(path)
      path = URI.parser.unescape(path)
      return false unless path.valid_encoding?
      return false unless base_of_path_exists_in_root_directory?(path)

      paths = [path, "#{path}#{ext}", "#{path}/index#{ext}"].map { |v|
        Rack::Utils.clean_path_info v
      }

      if match = paths.detect { |p|
        path = File.join(@root, p)
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

      # This method stores the existance of all files and directories in the
      # root of the  FileHandler directory in a hash. This information can
      # be used for quickly determining if a request should check the disk
      # or not.
      #
      # Example: If the root directory has a `404.html` and `500.html` file:
      #
      #   parse_root # => {"404.html" => true, "500.html" => true }
      #
      # The a root file named `index.html` is given special treatment.
      # Requests to `/index.html`, `/index` and `/` should all serve the
      # `index.html` file if it exists.
      def parse_root
        base_hash = {}
        return base_hash unless Dir.exist?(@root)
        Dir.entries(@root).each do |file|
          file = File.basename(file)
          base_hash[file] = true
          file.match(/(?<root>.*).html$/) do |match|
            base_hash[match[:root]] = true
          end
        end
        base_hash[nil] = true if base_hash["index"]
        base_hash
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
    def initialize(app, path, *file_handler_args)
      @app = app
      @file_handler = FileHandler.new(path, *file_handler_args)
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
