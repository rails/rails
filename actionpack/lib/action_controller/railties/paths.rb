module ActionController
  module Railties
    module Paths
      def self.with(app)
        Module.new do
          define_method(:inherited) do |klass|
            super(klass)

            if namespace = klass.parents.detect {|m| m.respond_to?(:_railtie) }
              paths = namespace._railtie.paths["app/helpers"].existent
            else
              paths = app.config.helpers_paths
            end

            klass.helpers_path = paths
            if klass.superclass == ActionController::Base && ActionController::Base.include_all_helpers
              klass.helper :all
            end

            if app.config.serve_static_assets && namespace
              paths = namespace._railtie.config.paths

              klass.config.assets_dir      = paths["public"].first
              klass.config.javascripts_dir = paths["public/javascripts"].first
              klass.config.stylesheets_dir = paths["public/stylesheets"].first
            end
          end
        end
      end
    end
  end
end
