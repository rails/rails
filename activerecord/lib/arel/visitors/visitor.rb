# frozen_string_literal: true

module Arel # :nodoc: all
  module Visitors
    class Visitor
      def initialize
        @dispatch = get_dispatch_cache
      end

      def accept(object, collector = nil)
        visit object, collector
      end

      private
        attr_reader :dispatch

        def self.dispatch_cache
          @dispatch_cache ||= Hash.new do |hash, klass|
            hash[klass] = "visit_#{(klass.name || '').gsub('::', '_')}"
          end
        end

        def get_dispatch_cache
          self.class.dispatch_cache
        end

        def visit(object, collector = nil)
          dispatch_method = dispatch[object.class]
          if collector
            send dispatch_method, object, collector
          else
            send dispatch_method, object
          end
        rescue NoMethodError => e
          raise e if respond_to?(dispatch_method, true)
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
