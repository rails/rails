# frozen_string_literal: true

module ActiveSupport
  class Deprecation
    module DeprecatedConstantAccessor
      def self.included(base)
        require "active_support/inflector/methods"

        extension = Module.new do
          def const_missing(missing_const_name)
            if class_variable_defined?(:@@_deprecated_constants)
              if (replacement = class_variable_get(:@@_deprecated_constants)[missing_const_name.to_s])
                replacement[:deprecator].warn(replacement[:message] || "#{name}::#{missing_const_name} is deprecated! Use #{replacement[:new]} instead.", caller_locations)
                return ActiveSupport::Inflector.constantize(replacement[:new].to_s)
              end
            end
            super
          end

          # Provides a way to rename constants with a deprecation cycle in which
          # both the old and new names work, but using the old one prints a
          # deprecation message.
          #
          # In order to rename <tt>A::B</tt> to <tt>C::D</tt>, you need to delete the
          # definition of <tt>A::B</tt> and declare the deprecation in +A+:
          #
          #   require "active_support/deprecation"
          #
          #   module A
          #     include ActiveSupport::Deprecation::DeprecatedConstantAccessor
          #
          #     deprecate_constant "B", "C::D", deprecator: ActiveSupport::Deprecation.new
          #   end
          #
          # The first argument is a constant name (no colons). It is the name of
          # the constant you want to deprecate in the enclosing class or module.
          #
          # The second argument is the constant path of the replacement. That
          # has to be a full path even if the replacement is defined in the same
          # namespace as the deprecated one was.
          #
          # In both cases, strings and symbols are supported.
          #
          # The +deprecator+ keyword argument is the object that will print the
          # deprecation message, an instance of ActiveSupport::Deprecation.
          #
          # With that in place, references to <tt>A::B</tt> still work, they
          # evaluate to <tt>C::D</tt> now, and trigger a deprecation warning:
          #
          #   DEPRECATION WARNING: A::B is deprecated! Use C::D instead.
          #   (called from ...)
          #
          # The message can be customized with the optional +message+ keyword
          # argument.
          #
          # For this to work, a +const_missing+ hook is installed. When client
          # code references the deprecated constant, the callback prints the
          # message and constantizes the replacement.
          #
          # Caveat: If the deprecated constant name is reachable in a different
          # namespace and Ruby constant lookup finds it, the hook won't be
          # called and the deprecation won't work as intended. This may happen,
          # for example, if an ancestor of the enclosing namespace has a
          # constant with the same name. This is an unsupported edge case.
          def deprecate_constant(old_constant_name, new_constant_path, deprecator:, message: nil)
            class_variable_set(:@@_deprecated_constants, {}) unless class_variable_defined?(:@@_deprecated_constants)
            class_variable_get(:@@_deprecated_constants)[old_constant_name.to_s] = { new: new_constant_path, message: message, deprecator: deprecator }
          end
        end
        base.singleton_class.prepend extension
      end
    end
  end
end
