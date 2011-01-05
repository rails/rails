module Arel
  module Visitors
    class Visitor
      def accept object
        visit object
      end

      private

      DISPATCH = Hash.new do |hash, klass|
        hash[klass] = "visit_#{(klass.name || '').gsub('::', '_')}"
      end

      def visit object
        send DISPATCH[object.class], object
      rescue NoMethodError => e
        raise e if respond_to?(DISPATCH[object.class], true)
        superklass = object.class.ancestors.find { |klass|
          respond_to?(DISPATCH[klass], true)
        }
        raise(TypeError, "Cannot visit #{object.class}") unless superklass
        DISPATCH[object.class] = DISPATCH[superklass]
        retry
      end
    end
  end
end
