module ActionMailer
  module Railties
    module RoutesHelpers
      def inherited(klass)
        super(klass)
        if namespace = klass.parents.detect {|m| m.respond_to?(:_railtie) }
          klass.send(:include, namespace._railtie.routes.url_helpers)
        end
      end
    end
  end
end
