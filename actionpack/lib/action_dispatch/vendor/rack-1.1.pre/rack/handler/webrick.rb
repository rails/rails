require 'webrick'
require 'stringio'
require 'rack/content_length'

module Rack
  module Handler
    class WEBrick < ::WEBrick::HTTPServlet::AbstractServlet
      def self.run(app, options={})
        server = ::WEBrick::HTTPServer.new(options)
        server.mount "/", Rack::Handler::WEBrick, app
        trap(:INT) { server.shutdown }
        yield server  if block_given?
        server.start
      end

      def initialize(server, app)
        super server
        @app = Rack::ContentLength.new(app)
      end

      def service(req, res)
        env = req.meta_vars
        env.delete_if { |k, v| v.nil? }

        env.update({"rack.version" => [1,0],
                     "rack.input" => StringIO.new(req.body.to_s),
                     "rack.errors" => $stderr,

                     "rack.multithread" => true,
                     "rack.multiprocess" => false,
                     "rack.run_once" => false,

                     "rack.url_scheme" => ["yes", "on", "1"].include?(ENV["HTTPS"]) ? "https" : "http"
                   })

        env["HTTP_VERSION"] ||= env["SERVER_PROTOCOL"]
        env["QUERY_STRING"] ||= ""
        env["REQUEST_PATH"] ||= "/"
        if env["PATH_INFO"] == ""
          env.delete "PATH_INFO"
        else
          path, n = req.request_uri.path, env["SCRIPT_NAME"].length
          env["PATH_INFO"] = path[n, path.length-n]
        end

        status, headers, body = @app.call(env)
        begin
          res.status = status.to_i
          headers.each { |k, vs|
            if k.downcase == "set-cookie"
              res.cookies.concat vs.split("\n")
            else
              vs.split("\n").each { |v|
                res[k] = v
              }
            end
          }
          body.each { |part|
            res.body << part
          }
        ensure
          body.close  if body.respond_to? :close
        end
      end
    end
  end
end
