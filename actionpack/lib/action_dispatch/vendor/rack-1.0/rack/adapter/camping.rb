module Rack
  module Adapter
    class Camping
      def initialize(app)
        @app = app
      end

      def call(env)
        env["PATH_INFO"] ||= ""
        env["SCRIPT_NAME"] ||= ""
        controller = @app.run(env['rack.input'], env)
        h = controller.headers
        h.each_pair do |k,v|
          if v.kind_of? URI
            h[k] = v.to_s
          end
        end
        [controller.status, controller.headers, [controller.body.to_s]]
      end
    end
  end
end
