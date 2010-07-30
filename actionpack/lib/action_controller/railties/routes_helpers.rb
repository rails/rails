module ActionController
  module Railties
    module RoutesHelpers
      def self.with(routes)
        Module.new do
          define_method(:inherited) do |klass|
            super(klass)
            if namespace = klass.parents.detect {|m| m.respond_to?(:_railtie) }
              routes = namespace._railtie.routes
            end
            klass.send(:include, routes.url_helpers)
          end
        end
      end
    end
  end
end
