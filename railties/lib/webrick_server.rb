# Donated by Florian Gross

require 'webrick'
require 'cgi'
require 'stringio'

begin
  require 'dev-utils/debug'
  require 'irb/completion'

  module DevUtils::Debug  
    alias_method :breakpoint_without_io, :breakpoint unless method_defined?(:breakpoint_without_io)

    def breakpoint(name = nil, context = nil, &block)
      $new_stdin, $new_stdout = $stdin, $stdout
      $stdin, $stdout = $old_stdin, $old_stdout
      breakpoint_without_io(name, context, &block)
      $stdin, $stdout = $new_stdin, $new_stdout
    end
  end
rescue LoadError
  # dev utils not available
end

include WEBrick

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
    @file_handler = WEBrick::HTTPServlet::FileHandler.new(server, options[:server_root], {:FancyIndexing => true })
    super
  end

  def do_GET(req, res)
    begin
      REQUEST_MUTEX.lock

      unless handle_index(req, res)
        unless handle_dispatch(req, res)
          unless handle_file(req, res)
            unless handle_mapped(req, res)
              raise WEBrick::HTTPStatus::NotFound, "`#{req.path}' not found."
            end
          end
        end
      end
    ensure
      REQUEST_MUTEX.unlock
    end
  end

  alias :do_POST :do_GET

  def handle_index(req, res)
    if req.request_uri.path == "/"
      if @server_options[:index_controller]
        res.set_redirect WEBrick::HTTPStatus::MovedPermanently, "/#{@server_options[:index_controller]}/"
      else
        res.set_redirect WEBrick::HTTPStatus::MovedPermanently, "/_doc/index.html"
      end

      return true
    else
      return false
    end
  end

  def handle_file(req, res)
    begin
      @file_handler.send(:do_GET, req, res)
      return true
    rescue HTTPStatus::PartialContent, HTTPStatus::NotModified => err
      res.set_error(err)
      return true
    rescue => err
      p err
      return false
    end
  end

  def handle_mapped(req, res)
    parsed_ok, controller, action, id = DispatchServlet.parse_uri(req.request_uri.path)
    if parsed_ok
      query = "controller=#{controller}&action=#{action}&id=#{id}"
      query << "&#{req.request_uri.query}" if req.request_uri.query
      origin = req.request_uri.path + "?" + query
      req.request_uri.path = "/dispatch.rb"
      req.request_uri.query = query
      handle_dispatch(req, res, origin)
    else
      return false
    end
  end

  def handle_dispatch(req, res, origin = nil)
    return false unless /^\/dispatch\.(?:cgi|rb|fcgi)$/.match(req.request_uri.path)

    env = req.meta_vars.clone
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
    header.each { |key, val| res[key] = val.join(", ") }
    
    res.body = body
    return true
  rescue => err
    p err, err.backtrace
    return false
  end
  
  def self.parse_uri(path)
    component = /([-_a-zA-Z0-9]+)/

    case path.sub(%r{^/(?:fcgi|mruby|cgi)/}, "/")
      when %r{^/#{component}/?$} then
        [true, $1, "index", nil]
      when %r{^/#{component}/#{component}/?$} then
        [true, $1, $2, nil]
      when %r{^/#{component}/#{component}/#{component}/?$} then
        [true, $1, $2, $3]
      else
        [false, nil, nil, nil]
    end
  end  
end
