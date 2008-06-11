module Rails
  module Rack
    class Static
      FILE_METHODS = %w(GET HEAD).freeze

      def initialize(app)
        @app = app
        @file_server = ::Rack::File.new(File.join(RAILS_ROOT, "public"))
      end

      def call(env)
        path        = env['PATH_INFO'].chomp('/')
        method      = env['REQUEST_METHOD']
        cached_path = (path.empty? ? 'index' : path) + ::ActionController::Base.page_cache_extension

        if FILE_METHODS.include?(method)
          if file_exist?(path)
            return @file_server.call(env)
          elsif file_exist?(cached_path)
            env['PATH_INFO'] = cached_path
            return @file_server.call(env)
          end
        end

        @app.call(env)
      end

      private
        def file_exist?(path)
          full_path = File.join(@file_server.root, ::Rack::Utils.unescape(path))
          File.file?(full_path) && File.readable?(full_path)
        end
    end
  end
end
