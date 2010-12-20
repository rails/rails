require 'action_dispatch/http/request'

module ActionDispatch
  module Routing
    module Redirection

      # Redirect any path to another path:
      #
      #   match "/stories" => redirect("/posts")
      #
      # You can also use interpolation in the supplied redirect argument:
      #
      #   match 'docs/:article', :to => redirect('/wiki/%{article}')
      #
      # Alternatively you can use one of the other syntaxes:
      #
      # The block version of redirect allows for the easy encapsulation of any logic associated with
      # the redirect in question. Either the params and request are supplied as arguments, or just
      # params, depending of how many arguments your block accepts. A string is required as a
      # return value.
      #
      #   match 'jokes/:number', :to => redirect do |params, request|
      #     path = (params[:number].to_i.even? ? "/wheres-the-beef" : "/i-love-lamp")
      #     "http://#{request.host_with_port}/#{path}"
      #   end
      #
      # The options version of redirect allows you to supply only the parts of the url which need
      # to change, it also supports interpolation of the path similar to the first example.
      #
      #   match 'stores/:name',       :to => redirect(:subdomain => 'stores', :path => '/%{name}')
      #   match 'stores/:name(*all)', :to => redirect(:subdomain => 'stores', :path => '/%{name}%{all}')
      #
      # Finally, an object which responds to call can be supplied to redirect, allowing you to reuse
      # common redirect routes. The call method must accept two arguments, params and request, and return
      # a string.
      #
      #   match 'accounts/:name' => redirect(SubdomainRedirector.new('api'))
      #
      def redirect(*args, &block)
        options = args.last.is_a?(Hash) ? args.pop : {}
        status  = options.delete(:status) || 301

        path = args.shift

        path_proc = if path.is_a?(String)
          proc { |params| (params.empty? || !path.match(/%\{\w*\}/)) ? path : (path % params) }
        elsif options.any?
          options_proc(options)
        elsif path.respond_to?(:call)
          proc { |params, request| path.call(params, request) }
        elsif block
          block
        else
          raise ArgumentError, "redirection argument not supported"
        end

        redirection_proc(status, path_proc)
      end

      private

        def options_proc(options)
          proc do |params, request|
            path = if options[:path].nil?
              request.path
            elsif params.empty? || !options[:path].match(/%\{\w*\}/)
              options.delete(:path)
            else
              (options.delete(:path) % params)
            end

            default_options = {
              :protocol => request.protocol,
              :host => request.host,
              :port => request.optional_port,
              :path => path,
              :params => request.query_parameters
            }

            ActionDispatch::Http::URL.url_for(options.reverse_merge(default_options))
          end
        end

        def redirection_proc(status, path_proc)
          lambda do |env|
            req = Request.new(env)

            params = [req.symbolized_path_parameters]
            params << req if path_proc.arity > 1

            uri = URI.parse(path_proc.call(*params))
            uri.scheme ||= req.scheme
            uri.host   ||= req.host
            uri.port   ||= req.port unless req.standard_port?

            body = %(<html><body>You are being <a href="#{ERB::Util.h(uri.to_s)}">redirected</a>.</body></html>)

            headers = {
              'Location' => uri.to_s,
              'Content-Type' => 'text/html',
              'Content-Length' => body.length.to_s
            }

            [ status, headers, [body] ]
          end
        end

    end
  end
end