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

      class NullReq # :nodoc:
        attr_reader :env
        def initialize(env)
          @env = env
        end

        def request_method
          env['REQUEST_METHOD']
        end

        def path_info
          env['PATH_INFO']
        end

        def ip
          env['REMOTE_ADDR']
        end

        def [](k)
          env[k]
        end
      end

      attr_reader :request_class, :formatter
      attr_accessor :routes

      def initialize(routes, options)
        @options       = options
        @params_key    = options[:parameters_key]
        @request_class = options[:request_class] || NullReq
        @routes        = routes
      end

      def call(env)
        env['PATH_INFO'] = Utils.normalize_path(env['PATH_INFO'])

        find_routes(env).each do |match, parameters, route|
          script_name, path_info, set_params = env.values_at('SCRIPT_NAME',
                                                             'PATH_INFO',
                                                             @params_key)

          unless route.path.anchored
            env['SCRIPT_NAME'] = (script_name.to_s + match.to_s).chomp('/')
            env['PATH_INFO']   = match.post_match
          end

          env[@params_key] = (set_params || {}).merge parameters

          status, headers, body = route.app.call(env)

          if 'pass' == headers['X-Cascade']
            env['SCRIPT_NAME'] = script_name
            env['PATH_INFO']   = path_info
            env[@params_key]   = set_params
            next
          end

          return [status, headers, body]
        end

        return [404, {'X-Cascade' => 'pass'}, ['Not Found']]
      end

      def recognize(req)
        find_routes(req.env).each do |match, parameters, route|
          unless route.path.anchored
            req.env['SCRIPT_NAME'] = match.to_s
            req.env['PATH_INFO']   = match.post_match.sub(/^([^\/])/, '/\1')
          end

          yield(route, nil, parameters)
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
          data = simulator.match(path)
          data ? data.memos : []
        end

        def find_routes env
          req = request_class.new(env)

          routes = filter_routes(req.path_info).concat custom_routes.find_all { |r|
            r.path.match(req.path_info)
          }
          routes.concat get_routes_as_head(routes)

          routes.sort_by!(&:precedence).select! { |r| r.matches?(req) }

          routes.map! { |r|
            match_data  = r.path.match(req.path_info)
            match_names = match_data.names.map { |n| n.to_sym }
            match_values = match_data.captures.map { |v| v && Utils.unescape_uri(v) }
            info = Hash[match_names.zip(match_values).find_all { |_, y| y }]

            [match_data, r.defaults.merge(info), r]
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
