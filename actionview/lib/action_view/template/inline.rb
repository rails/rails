# frozen_string_literal: true

module ActionView #:nodoc:
  class Template #:nodoc:
    class Inline < Template #:nodoc:
      # This finalizer is needed (and exactly with a proc inside another proc)
      # otherwise templates leak in development.
      Finalizer = proc do |method_name, mod| # :nodoc:
        proc do
          mod.module_eval do
            remove_possible_method method_name
          end
        end
      end

      def compile(mod)
        super
        ObjectSpace.define_finalizer(self, Finalizer[method_name, mod])
      end
    end
  end
end
