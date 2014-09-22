require 'arel/visitors/visitor'

module Arel
  module Visitors
    class Reduce < Arel::Visitors::Visitor
      def accept object, collector
        visit object, collector
      end

      private

      def visit object, collector
        send dispatch[object.class.name], object, collector
      rescue NoMethodError => e
        raise e if respond_to?(dispatch[object.class.name], true)
        superklass = object.class.ancestors.find { |klass|
          respond_to?(dispatch[klass.name], true)
        }
        raise(TypeError, "Cannot visit #{object.class}") unless superklass
        dispatch[object.class.name] = dispatch[superklass.name]
        retry
      end
    end
  end
end
