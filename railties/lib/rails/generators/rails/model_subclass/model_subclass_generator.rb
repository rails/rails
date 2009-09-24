module Rails
  module Generators
    class ModelSubclassGenerator < Base
      desc "model_subclass is deprecated. Invoke model with --parent option instead."

      def say_deprecation_warn
         say self.class.desc
      end
    end
  end
end
