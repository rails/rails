require "action_dispatch/http/request"
require "active_support/core_ext/uri"
require "active_support/core_ext/array/extract_options"
require "rack/utils"
require "action_controller/metal/exceptions"
require "action_dispatch/routing/endpoint"

module ActionDispatch
  module Routing
    class Redirect < Endpoint # :nodoc:
      attr_reader :status, :block

      def initialize(status, block)
        @status = status
        @block  = block
      end

      def redirect?; true; end

      def call(env)
        serve Request.new env
      end

      def serve(req)
        uri = URI.parse(path(req.path_parameters, req))

        unless uri.host
          if relative_path?(uri.path)
            uri.path = "#{req.script_name}/#{uri.path}"
          elsif uri.path.empty?
            uri.path = req.script_name.empty? ? "/" : req.script_name
          end
        end

        uri.scheme ||= req.scheme
        uri.host   ||= req.host
        uri.port   ||= req.port unless req.standard_port?

        body = %(<html><body>You are being <a href="#{ERB::Util.unwrapped_html_escape(uri.to_s)}">redirected</a>.</body></html>)

        headers = {
          "Location" => uri.to_s,
          "Content-Type" => "text/html",
          "Content-Length" => body.length.to_s
        }

        [ status, headers, [body] ]
      end

      def path(params, request)
        block.call params, request
      end

      def inspect
        "redirect(#{status})"
      end

      private
        def relative_path?(path)
          path && !path.empty? && path[0] != "/"
        end

        def escape(params)
          Hash[params.map{ |k,v| [k, Rack::Utils.escape(v)] }]
        end

        def escape_fragment(params)
          Hash[params.map{ |k,v| [k, Journey::Router::Utils.escape_fragment(v)] }]
        end

        def escape_path(params)
          Hash[params.map{ |k,v| [k, Journey::Router::Utils.escape_path(v)] }]
        end
    end

    class PathRedirect < Redirect
      URL_PARTS = /\A([^?]+)?(\?[^#]+)?(#.+)?\z/

      def path(params, request)
        if block.match(URL_PARTS)
          path     = interpolation_required?($1, params) ? $1 % escape_path(params)     : $1
          query    = interpolation_required?($2, params) ? $2 % escape(params)          : $2
          fragment = interpolation_required?($3, params) ? $3 % escape_fragment(params) : $3

          "#{path}#{query}#{fragment}"
        else
          interpolation_required?(block, params) ? block % escape(params) : block
        end
      end

      def inspect
        "redirect(#{status}, #{block})"
      end

      private
        def interpolation_required?(string, params)
          !params.empty? && string && string.match(/%\{\w*\}/)
        end
    end

    class OptionRedirect < Redirect # :nodoc:
      alias :options :block

      def path(params, request)
        url_options = {
          protocol: request.protocol,
          host: request.host,
          port: request.optional_port,
          path: request.path,
          params: request.query_parameters
        }.merge! options

        if !params.empty? && url_options[:path].match(/%\{\w*\}/)
          url_options[:path] = (url_options[:path] % escape_path(params))
        end

        unless options[:host] || options[:domain]
          if relative_path?(url_options[:path])
            url_options[:path] = "/#{url_options[:path]}"
            url_options[:script_name] = request.script_name
          elsif url_options[:path].empty?
            url_options[:path] = request.script_name.empty? ? "/" : ""
            url_options[:script_name] = request.script_name
          end
        end

        ActionDispatch::Http::URL.url_for url_options
      end

      def inspect
        "redirect(#{status}, #{options.map{ |k,v| "#{k}: #{v}" }.join(', ')})"
      end
    end

    module Redirection

      # Redirect any path to another path:
      #
      #   get "/stories" => redirect("/posts")
      #
      # You can also use interpolation in the supplied redirect argument:
      #
      #   get 'docs/:article', to: redirect('/wiki/%{article}')
      #
      # Note that if you return a path without a leading slash then the url is prefixed with the
      # current SCRIPT_NAME environment variable. This is typically '/' but may be different in
      # a mounted engine or where the application is deployed to a subdirectory of a website.
      #
      # Alternatively you can use one of the other syntaxes:
      #
      # The block version of redirect allows for the easy encapsulation of any logic associated with
      # the redirect in question. Either the params and request are supplied as arguments, or just
      # params, depending of how many arguments your block accepts. A string is required as a
      # return value.
      #
      #   get 'jokes/:number', to: redirect { |params, request|
      #     path = (params[:number].to_i.even? ? "wheres-the-beef" : "i-love-lamp")
      #     "http://#{request.host_with_port}/#{path}"
      #   }
      #
      # Note that the +do end+ syntax for the redirect block wouldn't work, as Ruby would pass
      # the block to +get+ instead of +redirect+. Use <tt>{ ... }</tt> instead.
      #
      # The options version of redirect allows you to supply only the parts of the url which need
      # to change, it also supports interpolation of the path similar to the first example.
      #
      #   get 'stores/:name',       to: redirect(subdomain: 'stores', path: '/%{name}')
      #   get 'stores/:name(*all)', to: redirect(subdomain: 'stores', path: '/%{name}%{all}')
      #
      # Finally, an object which responds to call can be supplied to redirect, allowing you to reuse
      # common redirect routes. The call method must accept two arguments, params and request, and return
      # a string.
      #
      #   get 'accounts/:name' => redirect(SubdomainRedirector.new('api'))
      #
      def redirect(*args, &block)
        options = args.extract_options!
        status  = options.delete(:status) || 301
        path    = args.shift

        return OptionRedirect.new(status, options) if options.any?
        return PathRedirect.new(status, path) if String === path

        block = path if path.respond_to? :call
        raise ArgumentError, "redirection argument not supported" unless block
        Redirect.new status, block
      end
    end
  end
end
