require 'time'

module Rack
  # Rack::File serves files below the +root+ given, according to the
  # path info of the Rack request.
  #
  # Handlers can detect if bodies are a Rack::File, and use mechanisms
  # like sendfile on the +path+.

  class File
    attr_accessor :root
    attr_accessor :path

    def initialize(root)
      @root = root
    end

    def call(env)
      dup._call(env)
    end

    F = ::File

    def _call(env)
      if env["PATH_INFO"].include? ".."
        body = "Forbidden\n"
        size = body.respond_to?(:bytesize) ? body.bytesize : body.size
        return [403, {"Content-Type" => "text/plain","Content-Length" => size.to_s}, [body]]
      end

      @path = F.join(@root, Utils.unescape(env["PATH_INFO"]))
      ext = F.extname(@path)[1..-1]

      if F.file?(@path) && F.readable?(@path)
        [200, {
           "Last-Modified"  => F.mtime(@path).httpdate,
           "Content-Type"   => MIME_TYPES[ext] || "text/plain",
           "Content-Length" => F.size(@path).to_s
         }, self]
      else
        body = "File not found: #{env["PATH_INFO"]}\n"
        size = body.respond_to?(:bytesize) ? body.bytesize : body.size
        [404, {"Content-Type" => "text/plain", "Content-Length" => size.to_s}, [body]]
      end
    end

    def each
      F.open(@path, "rb") { |file|
        while part = file.read(8192)
          yield part
        end
      }
    end

    # :stopdoc:
    # From WEBrick with some additions.
    MIME_TYPES = {
      "ai"    => "application/postscript",
      "asc"   => "text/plain",
      "avi"   => "video/x-msvideo",
      "bin"   => "application/octet-stream",
      "bmp"   => "image/bmp",
      "class" => "application/octet-stream",
      "cer"   => "application/pkix-cert",
      "crl"   => "application/pkix-crl",
      "crt"   => "application/x-x509-ca-cert",
     #"crl"   => "application/x-pkcs7-crl",
      "css"   => "text/css",
      "dms"   => "application/octet-stream",
      "doc"   => "application/msword",
      "dvi"   => "application/x-dvi",
      "eps"   => "application/postscript",
      "etx"   => "text/x-setext",
      "exe"   => "application/octet-stream",
      "gif"   => "image/gif",
      "htm"   => "text/html",
      "html"  => "text/html",
      "jpe"   => "image/jpeg",
      "jpeg"  => "image/jpeg",
      "jpg"   => "image/jpeg",
      "js"    => "text/javascript",
      "lha"   => "application/octet-stream",
      "lzh"   => "application/octet-stream",
      "mov"   => "video/quicktime",
      "mp3"   => "audio/mpeg",
      "mpe"   => "video/mpeg",
      "mpeg"  => "video/mpeg",
      "mpg"   => "video/mpeg",
      "pbm"   => "image/x-portable-bitmap",
      "pdf"   => "application/pdf",
      "pgm"   => "image/x-portable-graymap",
      "png"   => "image/png",
      "pnm"   => "image/x-portable-anymap",
      "ppm"   => "image/x-portable-pixmap",
      "ppt"   => "application/vnd.ms-powerpoint",
      "ps"    => "application/postscript",
      "qt"    => "video/quicktime",
      "ras"   => "image/x-cmu-raster",
      "rb"    => "text/plain",
      "rd"    => "text/plain",
      "rtf"   => "application/rtf",
      "sgm"   => "text/sgml",
      "sgml"  => "text/sgml",
      "tif"   => "image/tiff",
      "tiff"  => "image/tiff",
      "txt"   => "text/plain",
      "xbm"   => "image/x-xbitmap",
      "xls"   => "application/vnd.ms-excel",
      "xml"   => "text/xml",
      "xpm"   => "image/x-xpixmap",
      "xwd"   => "image/x-xwindowdump",
      "zip"   => "application/zip",
    }
    # :startdoc:
  end
end
