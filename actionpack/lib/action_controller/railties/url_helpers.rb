module ActionController
  class Railtie
    module UrlHelpers
      def self.with(router)
        Module.new do
          define_method(:inherited) do |klass|
            super(klass)
            klass.send(:include, router.url_helpers)
          end
        end
      end
    end
  end
end