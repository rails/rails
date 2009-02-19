require "thin"

module Rack
  module Handler
    class Thin
      def self.run(app, options={})
        server = ::Thin::Server.new(options[:Host] || '0.0.0.0',
                                    options[:Port] || 8080,
                                    app)
        yield server if block_given?
        server.start
      end
    end
  end
end
