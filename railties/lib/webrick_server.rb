# Donated by Florian Gross

require 'webrick'
require 'cgi'
require 'stringio'

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
    @file_handler = WEBrick::HTTPServlet::FileHandler.new(server, options[:server_root])
    super
  end

  def do_GET(req, res)
    begin
      unless handle_index(req, res)
        unless handle_dispatch(req, res)
          unless handle_file(req, res)
            REQUEST_MUTEX.lock
            unless handle_mapped(req, res)
              raise WEBrick::HTTPStatus::NotFound, "`#{req.path}' not found."
            end
          end
        end
      end
    ensure
      REQUEST_MUTEX.unlock if REQUEST_MUTEX.locked?
    end
  end

  alias :do_POST :do_GET

  def handle_index(req, res)
    if req.request_uri.path == "/"
      if @server_options[:index_controller]
        res.set_redirect WEBrick::HTTPStatus::MovedPermanently, "/#{@server_options[:index_controller]}/"
      else
        res.set_redirect WEBrick::HTTPStatus::MovedPermanently, "/_doc/"
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
      return false
    end
  end

  def handle_mapped(req, res)
    if mappings = DispatchServlet.parse_uri(req.request_uri.path)
      query = mappings.collect { |pair| "#{pair.first}=#{pair.last}" }.join("&")
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
    component, id = /([-_a-zA-Z0-9]+)/, /([0-9]+)/

    case path.sub(%r{^/(?:fcgi|mruby|cgi)/}, "/")
      when %r{^/#{component}/?$} then
        { :controller => $1, :action => "index" }
      when %r{^/#{component}/#{component}$} then
        { :controller => $1, :action => $2 }
      when %r{^/#{component}/#{component}/#{id}$} then
        { :controller => $1, :action => $2, :id => $3 }

      when %r{^/#{component}/#{component}/$} then
        { :module => $1, :controller => $2, :action => "index" }
      when %r{^/#{component}/#{component}/#{component}$} then
        if DispatchServlet.modules(component).include?($1)
          { :module => $1, :controller => $2, :action => $3 }
        else
          { :controller => $1, :action => $2, :id => $3 }
        end
      when %r{^/#{component}/#{component}/#{component}/#{id}$} then
        { :module => $1, :controller => $2, :action => $3, :id => $4 }
      else
        false
    end
  end  

  def self.modules(module_pattern = '[^.]+')
    path = RAILS_ROOT + '/app/controllers'
    Dir.entries(path).grep(/^#{module_pattern}$/).find_all {|e| File.directory?("#{path}/#{e}")}
  end
end
