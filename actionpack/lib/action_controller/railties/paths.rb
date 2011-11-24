module ActionController
  module Railties
    module Paths
      def self.with(app)
        Module.new do
          define_method(:inherited) do |klass|
            super(klass)

            if namespace = klass.parents.detect { |m| m.respond_to?(:railtie_helpers_paths) }
              paths = namespace.railtie_helpers_paths
            else
              paths = app.helpers_paths
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
