# frozen_string_literal: true

# :markup: markdown

require "cgi/escape"
require "cgi/util" if RUBY_VERSION < "3.5"
require "action_dispatch/journey/router/utils"
require "action_dispatch/journey/routes"
require "action_dispatch/journey/formatter"
require "action_dispatch/journey/parser"
require "action_dispatch/journey/route"
require "action_dispatch/journey/path/pattern"

module ActionDispatch
  module Journey # :nodoc:
    class Router # :nodoc:
      attr_accessor :routes

      def initialize(routes)
        @routes = routes
      end

      def eager_load!
        # Eagerly trigger the simulator's initialization so it doesn't happen during a
        # request cycle.
        simulator
        nil
      end

      def serve(req)
        recognize(req) do |route, parameters|
          req.path_parameters = parameters
          req.route = route

          _, headers, _ = response = route.app.serve(req)

          return response unless headers[Constants::X_CASCADE] == "pass"
        end

        [404, { Constants::X_CASCADE => "pass" }, ["Not Found"]]
      end

      def recognize(req, &block)
        req_params  = req.path_parameters
        path_info   = req.path_info
        script_name = req.script_name

        routes = filter_routes(path_info)

        custom_routes.each { |r|
          routes << r if r.path.match?(path_info)
        }

        if req.head?
          routes = match_head_routes(routes, req)
        else
          routes.select! { |r| r.matches?(req) }
        end

        if routes.size > 1
          routes.sort! do |a, b|
            a.precedence <=> b.precedence
          end
        end

        routes.each do |r|
          match_data = r.path.match(path_info)

          path_parameters = req_params.merge r.defaults

          index = 1
          match_data.names.each do |name|
            if val = match_data[index]
              val = if val.include?("%")
                CGI.unescapeURIComponent(val)
              else
                val
              end
              val.force_encoding(::Encoding::UTF_8)
              path_parameters[name.to_sym] = val
            end
            index += 1
          end

          if r.path.anchored
            yield(r, path_parameters)
          else
            req.script_name = (script_name.to_s + match_data.to_s).chomp("/")
            req.path_info = match_data.post_match
            req.path_info = "/" + req.path_info unless req.path_info.start_with? "/"

            yield(r, path_parameters)

            req.script_name     = script_name
            req.path_info       = path_info
          end

          req.path_parameters = req_params
        end
      end

      private
        def simulator
          routes.simulator
        end

        def custom_routes
          routes.custom_routes
        end

        def filter_routes(path)
          simulator.memos(path) { [] }
        end

        def match_head_routes(routes, req)
          head_routes = routes.select { |r| r.requires_matching_verb? && r.matches?(req) }
          return head_routes unless head_routes.empty?

          begin
            req.request_method = "GET"
            routes.select! { |r| r.matches?(req) }
            routes
          ensure
            req.request_method = "HEAD"
          end
        end
    end
  end
end
