module AbstractController
  module Railties
    module RoutesHelpers
      def self.with(routes)
        Module.new do
          define_method(:inherited) do |klass|
            super(klass)
            if namespace = klass.parents.detect {|m| m.respond_to?(:_railtie) }
              klass.send(:include, namespace._railtie.routes.url_helpers)
            else
              klass.send(:include, routes.url_helpers)
            end
          end
        end
      end
    end
  end
end
