module ActionMailer
  module AdvAttrAccessor #:nodoc:
    def self.append_features(base)
      super
      base.extend(ClassMethods)
    end

    module ClassMethods #:nodoc:
      def adv_attr_accessor(*names)
        names.each do |name|
          define_method("#{name}=") do |value|
            instance_variable_set("@#{name}", value)
          end

          define_method(name) do |*parameters|
            raise ArgumentError, "expected 0 or 1 parameters" unless parameters.length <= 1
            if parameters.empty?
              instance_variable_get("@#{name}")
            else
              instance_variable_set("@#{name}", parameters.first)
            end
          end
        end
      end
    end
  end
end
