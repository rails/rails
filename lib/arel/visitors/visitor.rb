module Arel
  module Visitors
    class Visitor
      def initialize
        @dispatch = get_dispatch_cache
      end

      def accept object
        visit object
      end

      private

      def self.dispatch_cache
        dispatch = Hash.new do |hash, class_name|
          hash[class_name] = "visit_#{(class_name || '').gsub('::', '_')}"
        end

        # pre-populate cache. FIXME: this should be passed in to each
        # instance, but we can do that later.
        self.class.private_instance_methods.sort.each do |name|
          next unless name =~ /^visit_(.*)$/
          dispatch[$1.gsub('_', '::')] = name
        end
        dispatch
      end

      def get_dispatch_cache
        self.class.dispatch_cache
      end

      def dispatch
        @dispatch
      end

      def visit object
        send dispatch[object.class.name], object
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
