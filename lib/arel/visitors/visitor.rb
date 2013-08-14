module Arel
  module Visitors
    class Visitor
      def accept object
        visit object
      end

      private

      DISPATCH = Hash.new do |hash, visitor_class|
        hash[visitor_class] =
          Hash.new do |hash, node_class|
            hash[node_class] = "visit_#{(node_class.name || '').gsub('::', '_')}"
          end
      end

      def dispatch
        DISPATCH[self.class]
      end

      def visit object, attribute = nil
        send dispatch[object.class], object, attribute
      rescue NoMethodError => e
        raise e if respond_to?(dispatch[object.class], true)
        superklass = object.class.ancestors.find { |klass|
          respond_to?(dispatch[klass], true)
        }
        raise(TypeError, "Cannot visit #{object.class}") unless superklass
        dispatch[object.class] = dispatch[superklass]
        retry
      end
    end
  end
end
