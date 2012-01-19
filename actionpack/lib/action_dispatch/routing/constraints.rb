module ActionDispatch
  module Routing
    class Constraints #:nodoc:
      def self.new(app, constraints, request = Rack::Request)
        if constraints.any?
          super(app, constraints, request)
        else
          app
        end
      end

      attr_reader :app, :constraints

      def initialize(app, constraints, request)
        @app, @constraints, @request = app, constraints, request
      end

      def matches?(env)
        req = @request.new(env)

        @constraints.each { |constraint|
          if constraint.respond_to?(:matches?) && !constraint.matches?(req)
            return false
          elsif constraint.respond_to?(:call) && !constraint.call(*constraint_args(constraint, req))
            return false
          end
        }

        return true
      end

      def call(env)
        matches?(env) ? @app.call(env) : [ 404, {'X-Cascade' => 'pass'}, [] ]
      end

      private
        def constraint_args(constraint, request)
          constraint.arity == 1 ? [request] : [request.symbolized_path_parameters, request]
        end
    end
  end
end
