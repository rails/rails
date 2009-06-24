require 'active_support/core_ext/module/deprecation'
require 'active_support/core_ext/module/aliasing'

module ActiveSupport
  class << Deprecation
    # Declare that a method has been deprecated.
    def deprecate_methods(target_module, *method_names)
      options = method_names.extract_options!
      method_names += options.keys

      method_names.each do |method_name|
        target_module.alias_method_chain(method_name, :deprecation) do |target, punctuation|
          target_module.module_eval(<<-end_eval, __FILE__, __LINE__ + 1)
            def #{target}_with_deprecation#{punctuation}(*args, &block)          # def generate_secret_with_deprecation(*args, &block)
              ::ActiveSupport::Deprecation.warn(                                 #   ::ActiveSupport::Deprecation.warn(
                ::ActiveSupport::Deprecation.deprecated_method_warning(          #     ::ActiveSupport::Deprecation.deprecated_method_warning(
                  :#{method_name},                                               #       :generate_secret,
                  #{options[method_name].inspect}),                              #       "You should use ActiveSupport::SecureRandom.hex(64)"),
                caller                                                           #     caller
              )                                                                  #   )
              send(:#{target}_without_deprecation#{punctuation}, *args, &block)  #   send(:generate_secret_without_deprecation, *args, &block)
            end                                                                  # end
          end_eval
        end
      end
    end
  end
end
