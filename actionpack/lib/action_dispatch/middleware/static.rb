require 'rack/utils'

module ActionDispatch
  class Static
    class FileHandler
      def initialize(at, root)
        @at = at.chomp("/")
        @file_server = ::Rack::File.new(root)
      end

      def file_exist?(path)
        (path = full_readable_path(path)) && File.file?(path)
      end

      def directory_exist?(path)
        (path = full_readable_path(path)) && File.directory?(path)
      end

      def call(env)
        env["PATH_INFO"].gsub!(/^#{@at}/, "")
        @file_server.call(env)
      end

      private
        def includes_path?(path)
          @at == "" || path =~ /^#{@at}/
        end

        def full_readable_path(path)
          return unless includes_path?(path)
          path = path.gsub(/^#{@at}/, "")
          File.join(@file_server.root, ::Rack::Utils.unescape(path))
        end
    end

    FILE_METHODS = %w(GET HEAD).freeze

    def initialize(app, roots)
      @app = app
      roots = normalize_roots(roots)
      @file_handlers = file_handlers(roots)
    end

    def call(env)
      path   = env['PATH_INFO'].chomp('/')
      method = env['REQUEST_METHOD']

      if FILE_METHODS.include?(method)
        if file_handler = file_exist?(path)
          return file_handler.call(env)
        else
          cached_path = directory_exist?(path) ? "#{path}/index" : path
          cached_path += ::ActionController::Base.page_cache_extension

          if file_handler = file_exist?(cached_path)
            env['PATH_INFO'] = cached_path
            return file_handler.call(env)
          end
        end
      end

      @app.call(env)
    end

    private
      def file_exist?(path)
        @file_handlers.detect { |f| f.file_exist?(path) }
      end

      def directory_exist?(path)
        @file_handlers.detect { |f| f.directory_exist?(path) }
      end

      def normalize_roots(roots)
        roots.is_a?(Hash) ? roots : { "/" => roots.chomp("/") }
      end

      def file_handlers(roots)
        roots.map do |at, root|
          FileHandler.new(at, root)
        end
      end
  end
end
