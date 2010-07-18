module ActionController
  module Railties

    module UrlHelpers
      def self.with(routes)
        Module.new do
          define_method(:inherited) do |klass|
            super(klass)
            klass.send(:include, routes.url_helpers)
          end
        end
      end
    end

    module MountedHelpers
      def self.with(routes, name = nil)
        Module.new do
          define_method(:inherited) do |klass|
            super(klass)
            klass.send(:include, routes.mounted_helpers(name))
          end
        end
      end
    end
  end
end
