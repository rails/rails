require 'active_support/core_ext/module/deprecation'
require 'active_support/core_ext/module/aliasing'
require 'active_support/core_ext/array/extract_options'

module ActiveSupport
  class << Deprecation
    # Declare that a method has been deprecated.
    def deprecate_methods(target_module, *method_names)
      options = method_names.extract_options!
      method_names += options.keys

      method_names.each do |method_name|
        target_module.alias_method_chain(method_name, :deprecation) do |target, punctuation|
          target_module.module_eval(<<-end_eval, __FILE__, __LINE__ + 1)
            def #{target}_with_deprecation#{punctuation}(*args, &block)
              ::ActiveSupport::Deprecation.warn(
                ::ActiveSupport::Deprecation.deprecated_method_warning(
                  :#{method_name},
                  #{options[method_name].inspect}),
                caller
              )
              send(:#{target}_without_deprecation#{punctuation}, *args, &block)
            end
          end_eval
        end
      end
    end
  end
end
