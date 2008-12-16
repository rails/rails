require 'action_controller/cgi_ext'

module ActionController #:nodoc:
  class CGIHandler
    module ProperStream
      def each
        while line = gets
          yield line
        end
      end

      def read(*args)
        if args.empty?
          super || ""
        else
          super
        end
      end
    end

    def self.dispatch_cgi(app, cgi, out = $stdout)
      env = cgi.__send__(:env_table)
      env.delete "HTTP_CONTENT_LENGTH"

      cgi.stdinput.extend ProperStream

      env["SCRIPT_NAME"] = "" if env["SCRIPT_NAME"] == "/"

      env.update({
        "rack.version" => [0,1],
        "rack.input" => cgi.stdinput,
        "rack.errors" => $stderr,
        "rack.multithread" => false,
        "rack.multiprocess" => true,
        "rack.run_once" => false,
        "rack.url_scheme" => ["yes", "on", "1"].include?(env["HTTPS"]) ? "https" : "http"
      })

      env["QUERY_STRING"] ||= ""
      env["HTTP_VERSION"] ||= env["SERVER_PROTOCOL"]
      env["REQUEST_PATH"] ||= "/"
      env.delete "PATH_INFO" if env["PATH_INFO"] == ""

      status, headers, body = app.call(env)
      begin
        out.binmode if out.respond_to?(:binmode)
        out.sync = false if out.respond_to?(:sync=)

        headers['Status'] = status.to_s
        out.write(cgi.header(headers))

        body.each { |part|
          out.write part
          out.flush if out.respond_to?(:flush)
        }
      ensure
        body.close if body.respond_to?(:close)
      end
    end
  end

  class CgiRequest #:nodoc:
    DEFAULT_SESSION_OPTIONS = {
      :database_manager  => nil,
      :prefix            => "ruby_sess.",
      :session_path      => "/",
      :session_key       => "_session_id",
      :cookie_only       => true,
      :session_http_only => true
    }
  end
end
