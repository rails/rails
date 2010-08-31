module ActionMailer
  module AdvAttrAccessor #:nodoc:
    def adv_attr_accessor(name, deprecation=nil)
      ivar = "@#{name}"
      deprecation ||= "Please pass :#{name} as hash key to mail() instead"

      class_eval <<-ACCESSORS, __FILE__, __LINE__ + 1
        def #{name}=(value)
          ActiveSupport::Deprecation.warn "#{name}= is deprecated. #{deprecation}"
          #{ivar} = value
        end

        def #{name}(*args)
          raise ArgumentError, "expected 0 or 1 parameters" unless args.length <= 1
          if args.empty?
            ActiveSupport::Deprecation.warn "#{name}() is deprecated and will be removed in future versions."
            #{ivar} if instance_variable_names.include?(#{ivar.inspect})
          else
            ActiveSupport::Deprecation.warn "#{name}(value) is deprecated. #{deprecation}"
            #{ivar} = args.first
          end
        end
      ACCESSORS

      self.protected_instance_variables << ivar if self.respond_to?(:protected_instance_variables)
    end
  end
end
