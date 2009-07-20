module ActiveModel
  module APICompliant
    include Naming

    def self.extended(klass)
      klass.class_eval do
        include Validations
        include InstanceMethods
      end
    end
  
    module InstanceMethods
      def to_model
        if respond_to?(:new_record?)
          self.class.class_eval { def to_model() self end }
          to_model
        else
          raise "In order to be ActiveModel API compliant, you need to define " \
                "a new_record? method, which should return true if it has not " \
                "yet been persisted."
        end
      end
    end
  end
end