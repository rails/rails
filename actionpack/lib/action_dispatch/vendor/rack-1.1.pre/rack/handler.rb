module Rack
  # *Handlers* connect web servers with Rack.
  #
  # Rack includes Handlers for Mongrel, WEBrick, FastCGI, CGI, SCGI
  # and LiteSpeed.
  #
  # Handlers usually are activated by calling <tt>MyHandler.run(myapp)</tt>.
  # A second optional hash can be passed to include server-specific
  # configuration.
  module Handler
    def self.get(server)
      return unless server
      server = server.to_s

      if klass = @handlers[server]
        obj = Object
        klass.split("::").each { |x| obj = obj.const_get(x) }
        obj
      else
        try_require('rack/handler', server)
        const_get(server)
      end
    end

    # Transforms server-name constants to their canonical form as filenames,
    # then tries to require them but silences the LoadError if not found
    #
    # Naming convention:
    #
    #   Foo # => 'foo'
    #   FooBar # => 'foo_bar.rb'
    #   FooBAR # => 'foobar.rb'
    #   FOObar # => 'foobar.rb'
    #   FOOBAR # => 'foobar.rb'
    #   FooBarBaz # => 'foo_bar_baz.rb'
    def self.try_require(prefix, const_name)
      file = const_name.gsub(/^[A-Z]+/) { |pre| pre.downcase }.
        gsub(/[A-Z]+[^A-Z]/, '_\&').downcase

      require(::File.join(prefix, file))
    rescue LoadError
    end

    def self.register(server, klass)
      @handlers ||= {}
      @handlers[server] = klass
    end

    autoload :CGI, "rack/handler/cgi"
    autoload :FastCGI, "rack/handler/fastcgi"
    autoload :Mongrel, "rack/handler/mongrel"
    autoload :EventedMongrel, "rack/handler/evented_mongrel"
    autoload :SwiftipliedMongrel, "rack/handler/swiftiplied_mongrel"
    autoload :WEBrick, "rack/handler/webrick"
    autoload :LSWS, "rack/handler/lsws"
    autoload :SCGI, "rack/handler/scgi"
    autoload :Thin, "rack/handler/thin"

    register 'cgi', 'Rack::Handler::CGI'
    register 'fastcgi', 'Rack::Handler::FastCGI'
    register 'mongrel', 'Rack::Handler::Mongrel'
    register 'emongrel', 'Rack::Handler::EventedMongrel'
    register 'smongrel', 'Rack::Handler::SwiftipliedMongrel'
    register 'webrick', 'Rack::Handler::WEBrick'
    register 'lsws', 'Rack::Handler::LSWS'
    register 'scgi', 'Rack::Handler::SCGI'
    register 'thin', 'Rack::Handler::Thin'
  end
end
