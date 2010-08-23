module ActionController
  module Railties
    module Paths
      def self.with(app)
        Module.new do
          define_method(:inherited) do |klass|
            super(klass)
            if namespace = klass.parents.detect {|m| m.respond_to?(:_railtie) }
              klass.helpers_path = namespace._railtie.config.paths.app.helpers.to_a
            else
              klass.helpers_path = app.config.helpers_paths
            end

            klass.helper :all
          end
        end
      end
    end
  end
end
