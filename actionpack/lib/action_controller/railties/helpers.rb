module ActionController
  module Railties
    module Helpers
      def inherited(klass)
        super
        return unless klass.respond_to?(:helpers_path=)

        klass.helpers_path = if namespace = klass.parents.detect { |m| m.respond_to?(:railtie_helpers_paths) }
                               namespace.railtie_helpers_paths
                             else
                               ActionController::Helpers.helpers_path
                             end

        if klass.superclass == ActionController::Base && ActionController::Base.include_all_helpers
          klass.helper :all
        end
      end
    end
  end
end
