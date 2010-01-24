module ActionMailer
  module AdvAttrAccessor #:nodoc:
    def adv_attr_accessor(*names)
      names.each do |name|
        ivar = "@#{name}"

        class_eval <<-ACCESSORS, __FILE__, __LINE__ + 1
          def #{name}=(value)
            #{ivar} = value
          end

          def #{name}(*args)
            raise ArgumentError, "expected 0 or 1 parameters" unless args.length <= 1
            if args.empty?
              #{ivar} if instance_variable_names.include?(#{ivar.inspect})
            else
              #{ivar} = args.first
            end
          end
        ACCESSORS

        self.protected_instance_variables << ivar if self.respond_to?(:protected_instance_variables)
      end
    end
  end
end
