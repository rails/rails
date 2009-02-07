require 'time'
require 'rack/utils'
require 'rack/mime'

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
  <meta http-equiv="content-type" content="text/html; charset=utf-8" />
  <style type='text/css'>
table { width:100%%; }
.name { text-align:left; }
.size, .mtime { text-align:right; }
.type { width:11em; }
.mtime { width:15em; }
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
      @root = F.expand_path(root)
      @app = app || Rack::File.new(@root)
    end

    def call(env)
      dup._call(env)
    end

    F = ::File

    def _call(env)
      @env = env
      @script_name = env['SCRIPT_NAME']
      @path_info = Utils.unescape(env['PATH_INFO'])

      if forbidden = check_forbidden
        forbidden
      else
        @path = F.join(@root, @path_info)
        list_path
      end
    end

    def check_forbidden
      return unless @path_info.include? ".."

      body = "Forbidden\n"
      size = body.respond_to?(:bytesize) ? body.bytesize : body.size
      return [403, {"Content-Type" => "text/plain","Content-Length" => size.to_s}, [body]]
    end

    def list_directory
      @files = [['../','Parent Directory','','','']]
      glob = F.join(@path, '*')

      Dir[glob].sort.each do |node|
        stat = stat(node)
        next  unless stat
        basename = F.basename(node)
        ext = F.extname(node)

        url = F.join(@script_name, @path_info, basename)
        size = stat.size
        type = stat.directory? ? 'directory' : Mime.mime_type(ext)
        size = stat.directory? ? '-' : filesize_format(size)
        mtime = stat.mtime.httpdate

        @files << [ url, basename, size, type, mtime ]
      end

      return [ 200, {'Content-Type'=>'text/html; charset=utf-8'}, self ]
    end

    def stat(node, max = 10)
      F.stat(node)
    rescue Errno::ENOENT, Errno::ELOOP
      return nil
    end

    # TODO: add correct response if not readable, not sure if 404 is the best
    #       option
    def list_path
      @stat = F.stat(@path)

      if @stat.readable?
        return @app.call(@env) if @stat.file?
        return list_directory if @stat.directory?
      else
        raise Errno::ENOENT, 'No such file or directory'
      end

    rescue Errno::ENOENT, Errno::ELOOP
      return entity_not_found
    end

    def entity_not_found
      body = "Entity not found: #{@path_info}\n"
      size = body.respond_to?(:bytesize) ? body.bytesize : body.size
      return [404, {"Content-Type" => "text/plain", "Content-Length" => size.to_s}, [body]]
    end

    def each
      show_path = @path.sub(/^#{@root}/,'')
      files = @files.map{|f| DIR_FILE % f }*"\n"
      page  = DIR_PAGE % [ show_path, show_path , files ]
      page.each_line{|l| yield l }
    end

    # Stolen from Ramaze

    FILESIZE_FORMAT = [
      ['%.1fT', 1 << 40],
      ['%.1fG', 1 << 30],
      ['%.1fM', 1 << 20],
      ['%.1fK', 1 << 10],
    ]

    def filesize_format(int)
      FILESIZE_FORMAT.each do |format, size|
        return format % (int.to_f / size) if int >= size
      end

      int.to_s + 'B'
    end
  end
end
