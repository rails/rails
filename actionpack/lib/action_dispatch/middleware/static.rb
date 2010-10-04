require 'rack/utils'

module ActionDispatch
  class FileHandler
    def initialize(at, root)
      @at, @root = at.chomp('/'), root.chomp('/')
      @compiled_at = (Regexp.compile(/^#{Regexp.escape(at)}/) unless @at.blank?)
      @compiled_root = Regexp.compile(/^#{Regexp.escape(root)}/)
      @file_server = ::Rack::File.new(@root)
    end

    def match?(path)
      path = path.dup
      if !@compiled_at || path.sub!(@compiled_at, '')
        full_path = path.empty? ? @root : File.join(@root, ::Rack::Utils.unescape(path))
        paths = "#{full_path}#{ext}"

        matches = Dir[paths]
        match = matches.detect { |m| File.file?(m) }
        if match
          match.sub!(@compiled_root, '')
          match
        end
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

    def initialize(app, roots)
      @app = app
      @file_handlers = create_file_handlers(roots)
    end

    def call(env)
      path   = env['PATH_INFO'].chomp('/')
      method = env['REQUEST_METHOD']

      if FILE_METHODS.include?(method)
        @file_handlers.each do |file_handler|
          if match = file_handler.match?(path)
            env["PATH_INFO"] = match
            return file_handler.call(env)
          end
        end
      end

      @app.call(env)
    end

    private
      def create_file_handlers(roots)
        roots = { '' => roots } unless roots.is_a?(Hash)

        roots.map do |at, root|
          FileHandler.new(at, root) if File.exist?(root)
        end.compact
      end
  end
end
