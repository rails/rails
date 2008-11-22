require 'time'

module Rack
  # Rack::Directory serves entries below the +root+ given, according to the
  # path info of the Rack request. If a directory is found, the file's contents
  # will be presented in an html based index. If a file is found, the env will
  # be passed to the specified +app+.
  #
  # If +app+ is not specified, a Rack::File of the same +root+ will be used.

  class Directory
    DIR_FILE = "<tr><td class='name'><a href='%s'>%s</a></td><td class='size'>%s</td><td class='type'>%s</td><td class='mtime'>%s</td></tr>"
    DIR_PAGE = <<-PAGE
<html><head>
  <title>%s</title>
  <style type='text/css'>
table { width:100%%; }
.name { text-align:left; }
.size, .mtime { text-align:right; }
  </style>
</head><body>
<h1>%s</h1>
<hr />
<table>
  <tr>
    <th class='name'>Name</th>
    <th class='size'>Size</th>
    <th class='type'>Type</th>
    <th class='mtime'>Last Modified</th>
  </tr>
%s
</table>
<hr />
</body></html>
    PAGE

    attr_reader :files
    attr_accessor :root, :path

    def initialize(root, app=nil)
      @root = root
      @app = app
      unless defined? @app
        @app = Rack::File.new(@root)
      end
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

      @path = F.join(@root, Utils.unescape(env['PATH_INFO']))

      if F.exist?(@path) and F.readable?(@path)
        if F.file?(@path)
          return @app.call(env)
        elsif F.directory?(@path)
          @files = [['../','Parent Directory','','','']]
          sName, pInfo = env.values_at('SCRIPT_NAME', 'PATH_INFO')
          Dir.entries(@path).sort.each do |file|
            next if file[0] == ?.
            fl    = F.join(@path, file)
            sz    = F.size(fl)
            url   = F.join(sName, pInfo, file)
            type  = F.directory?(fl) ? 'directory' :
              MIME_TYPES.fetch(F.extname(file)[1..-1],'unknown')
            size  = (type!='directory' ? (sz<10240 ? "#{sz}B" : "#{sz/1024}KB") : '-')
            mtime = F.mtime(fl).httpdate
            @files << [ url, file, size, type, mtime ]
          end
          return [ 200, {'Content-Type'=>'text/html'}, self ]
        end
      end

      body = "Entity not found: #{env["PATH_INFO"]}\n"
      size = body.respond_to?(:bytesize) ? body.bytesize : body.size
      return [404, {"Content-Type" => "text/plain", "Content-Length" => size.to_s}, [body]]
    end

    def each
      show_path = @path.sub(/^#{@root}/,'')
      files = @files.map{|f| DIR_FILE % f }*"\n"
      page  = DIR_PAGE % [ show_path, show_path , files ]
      page.each_line{|l| yield l }
    end

    def each_entry
      @files.each{|e| yield e }
    end

    # From WEBrick.
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
  end
end
