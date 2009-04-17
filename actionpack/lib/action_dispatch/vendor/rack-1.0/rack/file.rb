require 'time'
require 'rack/utils'
require 'rack/mime'

module Rack
  # Rack::File serves files below the +root+ given, according to the
  # path info of the Rack request.
  #
  # Handlers can detect if bodies are a Rack::File, and use mechanisms
  # like sendfile on the +path+.

  class File
    attr_accessor :root
    attr_accessor :path

    alias :to_path :path

    def initialize(root)
      @root = root
    end

    def call(env)
      dup._call(env)
    end

    F = ::File

    def _call(env)
      @path_info = Utils.unescape(env["PATH_INFO"])
      return forbidden  if @path_info.include? ".."

      @path = F.join(@root, @path_info)

      begin
        if F.file?(@path) && F.readable?(@path)
          serving
        else
          raise Errno::EPERM
        end
      rescue SystemCallError
        not_found
      end
    end

    def forbidden
      body = "Forbidden\n"
      [403, {"Content-Type" => "text/plain",
             "Content-Length" => body.size.to_s},
       [body]]
    end

    # NOTE:
    #   We check via File::size? whether this file provides size info
    #   via stat (e.g. /proc files often don't), otherwise we have to
    #   figure it out by reading the whole file into memory. And while
    #   we're at it we also use this as body then.

    def serving
      if size = F.size?(@path)
        body = self
      else
        body = [F.read(@path)]
        size = Utils.bytesize(body.first)
      end

      [200, {
        "Last-Modified"  => F.mtime(@path).httpdate,
        "Content-Type"   => Mime.mime_type(F.extname(@path), 'text/plain'),
        "Content-Length" => size.to_s
      }, body]
    end

    def not_found
      body = "File not found: #{@path_info}\n"
      [404, {"Content-Type" => "text/plain",
         "Content-Length" => body.size.to_s},
       [body]]
    end

    def each
      F.open(@path, "rb") { |file|
        while part = file.read(8192)
          yield part
        end
      }
    end
  end
end
