module Rails
  module Rack
    class QuietAssets
      def initialize(app)
        @app = app
        @assets_regex = %r(\A/{0,2}#{Rails.application.config.assets.prefix})
      end

      def call(env)
        if env['PATH_INFO'] =~ @assets_regex
          Rails.logger.silence { @app.call(env) }
        else
          @app.call(env)
        end
      end
    end
  end
end
