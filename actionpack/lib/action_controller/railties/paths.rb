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
          end
        end
      end
    end
  end
end
