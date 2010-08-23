module ActionController
  module Railties
    module Paths
      def self.with(_app)
        Module.new do
          define_method(:inherited) do |klass|
            super(klass)
            if namespace = klass.parents.detect {|m| m.respond_to?(:_railtie) }
              app = namespace._railtie
            else
              app = _app
            end

            paths   = app.config.paths
            options = app.config.action_controller

            options.helpers_path         ||= paths.app.helpers.to_a
            options.each { |k,v| klass.send("#{k}=", v) }

            klass.helper :all
          end
        end
      end
    end
  end
end
