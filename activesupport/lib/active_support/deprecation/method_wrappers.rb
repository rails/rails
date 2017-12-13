require "active_support/core_ext/module/aliasing"
require "active_support/core_ext/array/extract_options"

module ActiveSupport
  class Deprecation
    module MethodWrapper
      # Declare that a method has been deprecated.
      #
      #   module Fred
      #     extend self
      #
      #     def aaa; end
      #     def bbb; end
      #     def ccc; end
      #     def ddd; end
      #     def eee; end
      #   end
      #
      # Using the default deprecator:
      #   ActiveSupport::Deprecation.deprecate_methods(Fred, :aaa, bbb: :zzz, ccc: 'use Bar#ccc instead')
      #   # => Fred
      #
      #   Fred.aaa
      #   # DEPRECATION WARNING: aaa is deprecated and will be removed from Rails 5.1. (called from irb_binding at (irb):10)
      #   # => nil
      #
      #   Fred.bbb
      #   # DEPRECATION WARNING: bbb is deprecated and will be removed from Rails 5.1 (use zzz instead). (called from irb_binding at (irb):11)
      #   # => nil
      #
      #   Fred.ccc
      #   # DEPRECATION WARNING: ccc is deprecated and will be removed from Rails 5.1 (use Bar#ccc instead). (called from irb_binding at (irb):12)
      #   # => nil
      #
      # Passing in a custom deprecator:
      #   custom_deprecator = ActiveSupport::Deprecation.new('next-release', 'MyGem')
      #   ActiveSupport::Deprecation.deprecate_methods(Fred, ddd: :zzz, deprecator: custom_deprecator)
      #   # => [:ddd]
      #
      #   Fred.ddd
      #   DEPRECATION WARNING: ddd is deprecated and will be removed from MyGem next-release (use zzz instead). (called from irb_binding at (irb):15)
      #   # => nil
      #
      # Using a custom deprecator directly:
      #   custom_deprecator = ActiveSupport::Deprecation.new('next-release', 'MyGem')
      #   custom_deprecator.deprecate_methods(Fred, eee: :zzz)
      #   # => [:eee]
      #
      #   Fred.eee
      #   DEPRECATION WARNING: eee is deprecated and will be removed from MyGem next-release (use zzz instead). (called from irb_binding at (irb):18)
      #   # => nil
      def deprecate_methods(target_module, *method_names)
        options = method_names.extract_options!
        deprecator = options.delete(:deprecator) || self
        method_names += options.keys

        mod = Module.new do
          method_names.each do |method_name|
            define_method(method_name) do |*args, &block|
              deprecator.deprecation_warning(method_name, options[method_name])
              super(*args, &block)
            end

            case
            when target_module.protected_method_defined?(method_name)
              protected method_name
            when target_module.private_method_defined?(method_name)
              private method_name
            end
          end
        end

        target_module.prepend(mod)
      end
    end
  end
end
