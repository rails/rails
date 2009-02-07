require 'fcgi'
require 'socket'

module Rack
  module Handler
    class FastCGI
      def self.run(app, options={})
        file = options[:File] and STDIN.reopen(UNIXServer.new(file))
        port = options[:Port] and STDIN.reopen(TCPServer.new(port))
        FCGI.each { |request|
          serve request, app
        }
      end

      module ProperStream       # :nodoc:
        def each                # This is missing by default.
          while line = gets
            yield line
          end
        end

        def read(*args)
          if args.empty?
            super || ""           # Empty string on EOF.
          else
            super
          end
        end
      end

      def self.serve(request, app)
        env = request.env
        env.delete "HTTP_CONTENT_LENGTH"

        request.in.extend ProperStream

        env["SCRIPT_NAME"] = ""  if env["SCRIPT_NAME"] == "/"

        env.update({"rack.version" => [0,1],
                     "rack.input" => request.in,
                     "rack.errors" => request.err,

                     "rack.multithread" => false,
                     "rack.multiprocess" => true,
                     "rack.run_once" => false,

                     "rack.url_scheme" => ["yes", "on", "1"].include?(env["HTTPS"]) ? "https" : "http"
                   })

        env["QUERY_STRING"] ||= ""
        env["HTTP_VERSION"] ||= env["SERVER_PROTOCOL"]
        env["REQUEST_PATH"] ||= "/"
        env.delete "PATH_INFO"  if env["PATH_INFO"] == ""
        env.delete "CONTENT_TYPE"  if env["CONTENT_TYPE"] == ""
        env.delete "CONTENT_LENGTH"  if env["CONTENT_LENGTH"] == ""

        status, headers, body = app.call(env)
        begin
          send_headers request.out, status, headers
          send_body request.out, body
        ensure
          body.close  if body.respond_to? :close
          request.finish
        end
      end

      def self.send_headers(out, status, headers)
        out.print "Status: #{status}\r\n"
        headers.each { |k, vs|
          vs.each { |v|
            out.print "#{k}: #{v}\r\n"
          }
        }
        out.print "\r\n"
        out.flush
      end

      def self.send_body(out, body)
        body.each { |part|
          out.print part
          out.flush
        }
      end
    end
  end
end
