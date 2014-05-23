require 'action_dispatch/journey/router/utils'
require 'action_dispatch/journey/router/strexp'
require 'action_dispatch/journey/routes'
require 'action_dispatch/journey/formatter'

before = $-w
$-w = false
require 'action_dispatch/journey/parser'
$-w = before

require 'action_dispatch/journey/route'
require 'action_dispatch/journey/path/pattern'

module ActionDispatch
  module Journey # :nodoc:
    class Router # :nodoc:
      class RoutingError < ::StandardError # :nodoc:
      end

      # :nodoc:
      VERSION = '2.0.0'

      attr_reader :request_class, :formatter
      attr_accessor :routes

      def initialize(routes, options)
        @options       = options
        @request_class = options[:request_class]
        @routes        = routes
      end

      def call(env)
        req = request_class.new(env)

        req.path_info = Utils.normalize_path(req.path_info)

        find_routes(env, req).each do |match, parameters, route|
          set_params  = req.path_parameters
          path_info   = req.path_info
          script_name = req.script_name

          unless route.path.anchored
            req.script_name = (script_name.to_s + match.to_s).chomp('/')
            req.path_info = match.post_match
          end

          req.path_parameters = set_params.merge parameters

          status, headers, body = route.app.call(env)

          if 'pass' == headers['X-Cascade']
            req.script_name     = script_name
            req.path_info       = path_info
            req.path_parameters = set_params
            next
          end

          return [status, headers, body]
        end

        return [404, {'X-Cascade' => 'pass'}, ['Not Found']]
      end

      def recognize(req)
        rails_req = request_class.new(req.env)

        find_routes(req.env, rails_req).each do |match, parameters, route|
          unless route.path.anchored
            req.env['SCRIPT_NAME'] = match.to_s
            req.env['PATH_INFO']   = match.post_match.sub(/^([^\/])/, '/\1')
          end

          yield(route, parameters)
        end
      end

      def visualizer
        tt     = GTG::Builder.new(ast).transition_table
        groups = partitioned_routes.first.map(&:ast).group_by { |a| a.to_s }
        asts   = groups.values.map { |v| v.first }
        tt.visualizer(asts)
      end

      private

        def partitioned_routes
          routes.partitioned_routes
        end

        def ast
          routes.ast
        end

        def simulator
          routes.simulator
        end

        def custom_routes
          partitioned_routes.last
        end

        def filter_routes(path)
          return [] unless ast
          simulator.memos(path) { [] }
        end

        def find_routes env, req
          routes = filter_routes(req.path_info).concat custom_routes.find_all { |r|
            r.path.match(req.path_info)
          }
          routes.concat get_routes_as_head(routes)

          routes.sort_by!(&:precedence).select! { |r| r.matches?(req) }

          routes.map! { |r|
            match_data  = r.path.match(req.path_info)
            path_parameters = r.defaults.dup
            match_data.names.zip(match_data.captures) { |name,val|
              path_parameters[name.to_sym] = Utils.unescape_uri(val) if val
            }
            [match_data, path_parameters, r]
          }
        end

        def get_routes_as_head(routes)
          precedence = (routes.map(&:precedence).max || 0) + 1
          routes = routes.select { |r|
            r.verb === "GET" && !(r.verb === "HEAD")
          }.map! { |r|
            Route.new(r.name,
                      r.app,
                      r.path,
                      r.conditions.merge(request_method: "HEAD"),
                      r.defaults).tap do |route|
                        route.precedence = r.precedence + precedence
                      end
          }
          routes.flatten!
          routes
        end
    end
  end
end
