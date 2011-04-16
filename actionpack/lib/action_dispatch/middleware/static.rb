require 'rack/utils'

module ActionDispatch
  class FileHandler
    def initialize(root)
      @root          = root.chomp('/')
      @compiled_root = /^#{Regexp.escape(root)}/
      @file_server   = ::Rack::File.new(@root)
    end

    def match?(path)
      path = path.dup

      full_path = path.empty? ? @root : File.join(@root, ::Rack::Utils.unescape(path))
      paths = "#{full_path}#{ext}"

      matches = Dir[paths]
      match = matches.detect { |m| File.file?(m) }
      if match
        match.sub!(@compiled_root, '')
        match
      end
    end

    def call(env)
      @file_server.call(env)
    end

    def ext
      @ext ||= begin
        ext = ::ActionController::Base.page_cache_extension
        "{,#{ext},/index#{ext}}"
      end
    end
  end

  class Static
    FILE_METHODS = %w(GET HEAD).freeze

    def initialize(app, path)
      @app = app
      @file_handler = FileHandler.new(path)
    end

    def call(env)
      path   = env['PATH_INFO'].chomp('/')
      method = env['REQUEST_METHOD']

      if FILE_METHODS.include?(method)
        if match = @file_handler.match?(path)
          env["PATH_INFO"] = match
          return @file_handler.call(env)
        end
      end

      @app.call(env)
    end
  end
end
