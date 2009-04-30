require 'rack/mock'

module Rack
  class MockRequest
    # Return the Rack environment used for a request to +uri+.
    def self.env_for(uri="", opts={})
      uri = URI(uri)
      uri.path = "/#{uri.path}" unless uri.path[0] == ?/

      env = DEFAULT_ENV.dup

      env["REQUEST_METHOD"] = opts[:method] ? opts[:method].to_s.upcase : "GET"
      env["SERVER_NAME"] = uri.host || "example.org"
      env["SERVER_PORT"] = uri.port ? uri.port.to_s : "80"
      env["QUERY_STRING"] = uri.query.to_s
      env["PATH_INFO"] = (!uri.path || uri.path.empty?) ? "/" : uri.path
      env["rack.url_scheme"] = uri.scheme || "http"
      env["HTTPS"] = env["rack.url_scheme"] == "https" ? "on" : "off"

      env["SCRIPT_NAME"] = opts[:script_name] || ""

      if opts[:fatal]
        env["rack.errors"] = FatalWarner.new
      else
        env["rack.errors"] = StringIO.new
      end

      if params = opts[:params]
        if env["REQUEST_METHOD"] == "GET"
          params = Utils.parse_nested_query(params) if params.is_a?(String)
          params.update(Utils.parse_nested_query(env["QUERY_STRING"]))
          env["QUERY_STRING"] = Utils.build_nested_query(params)
        elsif !opts.has_key?(:input)
          opts["CONTENT_TYPE"] = "application/x-www-form-urlencoded"
          if params.is_a?(Hash)
            if data = Utils::Multipart.build_multipart(params)
              opts[:input] = data
              opts["CONTENT_LENGTH"] ||= data.length.to_s
              opts["CONTENT_TYPE"] = "multipart/form-data; boundary=#{Utils::Multipart::MULTIPART_BOUNDARY}"
            else
              opts[:input] = Utils.build_nested_query(params)
            end
          else
            opts[:input] = params
          end
        end
      end

      opts[:input] ||= ""
      if String === opts[:input]
        env["rack.input"] = StringIO.new(opts[:input])
      else
        env["rack.input"] = opts[:input]
      end

      env["CONTENT_LENGTH"] ||= env["rack.input"].length.to_s

      opts.each { |field, value|
        env[field] = value  if String === field
      }

      env
    end
  end
end
