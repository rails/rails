module ActionMailer
  module AdvAttrAccessor #:nodoc:
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods #:nodoc:
      def adv_attr_accessor(*names)
        names.each do |name|
          ivar = "@#{name}"

          define_method("#{name}=") do |value|
            instance_variable_set(ivar, value)
          end

          define_method(name) do |*parameters|
            raise ArgumentError, "expected 0 or 1 parameters" unless parameters.length <= 1
            if parameters.empty?
              if instance_variables.include?(ivar)
                instance_variable_get(ivar)
              end
            else
              instance_variable_set(ivar, parameters.first)
            end
          end
        end
      end
    end
  end
end
