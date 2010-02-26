module ActionController
  class Railtie
    module UrlHelpers
      def self.with(router)
        Module.new do
          define_method(:inherited) do |klass|
            super
            klass.send(:include, router.named_url_helpers)
          end
        end
      end
    end
  end
end