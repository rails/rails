# Donated by Florian Gross

require 'webrick'
require 'cgi'
require 'stringio'

include WEBrick

ABSOLUTE_RAILS_ROOT = File.expand_path(RAILS_ROOT)

class DispatchServlet < WEBrick::HTTPServlet::AbstractServlet
  REQUEST_MUTEX = Mutex.new

  def self.dispatch(options = {})
    Socket.do_not_reverse_lookup = true # patch for OS X

    server = WEBrick::HTTPServer.new(:Port => options[:port].to_i, :ServerType => options[:server_type], :BindAddress => options[:ip])
    server.mount('/', DispatchServlet, options)

    trap("INT") { server.shutdown }
    server.start
  end

  def initialize(server, options)
    @server_options = options
    @file_handler = WEBrick::HTTPServlet::FileHandler.new(server, options[:server_root])
    Dir.chdir(ABSOLUTE_RAILS_ROOT)
    super
  end

  def service(req, res)
    begin
      unless handle_file(req, res)
        REQUEST_MUTEX.lock
        unless handle_dispatch(req, res)
          raise WEBrick::HTTPStatus::NotFound, "`#{req.path}' not found."
        end
      end
    ensure
      REQUEST_MUTEX.unlock if REQUEST_MUTEX.locked?
    end
  end

  def handle_file(req, res)
    begin
      add_dot_html(req)
      @file_handler.send(:service, req, res)
      remove_dot_html(req)
      return true
    rescue HTTPStatus::PartialContent, HTTPStatus::NotModified => err
      res.set_error(err)
      return true
    rescue => err
      return false
    ensure
      remove_dot_html(req)
    end
  end

  def add_dot_html(req)
    if /^([^.]+)$/ =~ req.path && req.path != "/" then req.instance_variable_set(:@path_info, "#{$1}.html") end
  end
  
  def remove_dot_html(req)
    if /^([^.]+).html$/ =~ req.path && req.path != "/" then req.instance_variable_set(:@path_info, $1) end
  end

  def handle_dispatch(req, res, origin = nil)
    env = req.meta_vars.clone
    env.delete "SCRIPT_NAME"
    env["QUERY_STRING"] = req.request_uri.query
    env["REQUEST_URI"] = origin if origin
    
    data = nil
    $old_stdin, $old_stdout = $stdin, $stdout
    $stdin, $stdout = StringIO.new(req.body || ""), StringIO.new

    begin
      require 'cgi'
      CGI.send(:define_method, :env_table) { env }

      load File.join(@server_options[:server_root], "dispatch.rb")

      $stdout.rewind
      data = $stdout.read
    ensure
      $stdin, $stdout = $old_stdin, $old_stdout
    end

    raw_header, body = *data.split(/^[\xd\xa]+/on, 2)
    header = WEBrick::HTTPUtils::parse_header(raw_header)
    if /^(\d+)/ =~ header['status'][0]
      res.status = $1.to_i
      header.delete('status')
    end
    res.cookies.concat header.delete('set-cookie')
    header.each { |key, val| res[key] = val.join(", ") }
    
    res.body = body
    return true
  rescue => err
    p err, err.backtrace
    return false
  end
end
