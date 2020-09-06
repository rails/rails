# frozen_string_literal: true

require 'rack/utils'
require 'active_support/core_ext/uri'

module ActionDispatch
  # This middleware serves static files from disk, if available.
  # If no file is found, it hands off to the main app.
  #
  # In Rails apps, this middleware is configured to serve assets from
  # the +public/+ directory.
  #
  # Only GET and HEAD requests are served. POST and other HTTP methods
  # are handed off to the main app.
  #
  # Only files in the root directory are served; path traversal is denied.
  class Static
    def initialize(app, path, index: 'index', headers: {})
      @app = app
      @file_handler = FileHandler.new(path, index: index, headers: headers)
    end

    def call(env)
      @file_handler.attempt(env) || @app.call(env)
    end
  end

  # This endpoint serves static files from disk using Rack::File.
  #
  # URL paths are matched with static files according to expected
  # conventions: +path+, +path+.html, +path+/index.html.
  #
  # Precompressed versions of these files are checked first. Brotli (.br)
  # and gzip (.gz) files are supported. If +path+.br exists, this
  # endpoint returns that file with a +Content-Encoding: br+ header.
  #
  # If no matching file is found, this endpoint responds 404 Not Found.
  #
  # Pass the +root+ directory to search for matching files, an optional
  # +index: "index"+ to change the default +path+/index.html, and optional
  # additional response headers.
  class FileHandler
    # Accept-Encoding value -> file extension
    PRECOMPRESSED = {
      'br' => '.br',
      'gzip' => '.gz',
      'identity' => nil
    }

    def initialize(root, index: 'index', headers: {}, precompressed: %i[ br gzip ], compressible_content_types: /\A(?:text\/|application\/javascript)/)
      @root = root.chomp('/').b
      @index = index

      @precompressed = Array(precompressed).map(&:to_s) | %w[ identity ]
      @compressible_content_types = compressible_content_types

      @file_server = ::Rack::File.new(@root, headers)
    end

    def call(env)
      attempt(env) || @file_server.call(env)
    end

    def attempt(env)
      request = Rack::Request.new env

      if request.get? || request.head?
        if found = find_file(request.path_info, accept_encoding: request.accept_encoding)
          serve request, *found
        end
      end
    end

    private
      def serve(request, filepath, content_headers)
        original, request.path_info =
          request.path_info, ::Rack::Utils.escape_path(filepath).b

        @file_server.call(request.env).tap do |status, headers, body|
          # Omit Content-Encoding/Type/etc headers for 304 Not Modified
          if status != 304
            headers.update(content_headers)
          end
        end
      ensure
        request.path_info = original
      end

      # Match a URI path to a static file to be served.
      #
      # Used by the +Static+ class to negotiate a servable file in the
      # +public/+ directory (see Static#call).
      #
      # Checks for +path+, +path+.html, and +path+/index.html files,
      # in that order, including .br and .gzip compressed extensions.
      #
      # If a matching file is found, the path and necessary response headers
      # (Content-Type, Content-Encoding) are returned.
      def find_file(path_info, accept_encoding:)
        each_candidate_filepath(path_info) do |filepath, content_type|
          if response = try_files(filepath, content_type, accept_encoding: accept_encoding)
            return response
          end
        end
      end

      def try_files(filepath, content_type, accept_encoding:)
        headers = { 'Content-Type' => content_type }

        if compressible? content_type
          try_precompressed_files filepath, headers, accept_encoding: accept_encoding
        elsif file_readable? filepath
          [ filepath, headers ]
        end
      end

      def try_precompressed_files(filepath, headers, accept_encoding:)
        each_precompressed_filepath(filepath) do |content_encoding, precompressed_filepath|
          if file_readable? precompressed_filepath
            # Identity encoding is default, so we skip Accept-Encoding
            # negotiation and needn't set Content-Encoding.
            #
            # Vary header is expected when we've found other available
            # encodings that Accept-Encoding ruled out.
            if content_encoding == 'identity'
              return precompressed_filepath, headers
            else
              headers['Vary'] = 'Accept-Encoding'

              if accept_encoding.any? { |enc, _| /\b#{content_encoding}\b/i.match?(enc) }
                headers['Content-Encoding'] = content_encoding
                return precompressed_filepath, headers
              end
            end
          end
        end
      end

      def file_readable?(path)
        file_stat = File.stat(File.join(@root, path.b))
      rescue SystemCallError
        false
      else
        file_stat.file? && file_stat.readable?
      end

      def compressible?(content_type)
        @compressible_content_types.match?(content_type)
      end

      def each_precompressed_filepath(filepath)
        @precompressed.each do |content_encoding|
          precompressed_ext = PRECOMPRESSED.fetch(content_encoding)
          yield content_encoding, "#{filepath}#{precompressed_ext}"
        end

        nil
      end

      def each_candidate_filepath(path_info)
        return unless path = clean_path(path_info)

        ext = ::File.extname(path)
        content_type = ::Rack::Mime.mime_type(ext, nil)
        yield path, content_type || 'text/plain'

        # Tack on .html and /index.html only for paths that don't have
        # an explicit, resolvable file extension. No need to check
        # for foo.js.html and foo.js/index.html.
        unless content_type
          default_ext = ::ActionController::Base.default_static_extension
          if ext != default_ext
            default_content_type = ::Rack::Mime.mime_type(default_ext, 'text/plain')

            yield "#{path}#{default_ext}", default_content_type
            yield "#{path}/#{@index}#{default_ext}", default_content_type
          end
        end

        nil
      end

      def clean_path(path_info)
        path = ::Rack::Utils.unescape_path path_info.chomp('/')
        if ::Rack::Utils.valid_path? path
          ::Rack::Utils.clean_path_info path
        end
      end
  end
end
