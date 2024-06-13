# frozen_string_literal: true

module ActiveSupport
  class CodeGenerator # :nodoc:
    class MethodSet
      METHOD_CACHES = Hash.new { |h, k| h[k] = Module.new }

      def initialize(namespace)
        @cache = METHOD_CACHES[namespace]
        @sources = []
        @methods = {}
        @canonical_methods = {}
      end

      def define_cached_method(canonical_name, as: nil)
        canonical_name = canonical_name.to_sym
        as = (as || canonical_name).to_sym

        @methods.fetch(as) do
          unless @cache.method_defined?(canonical_name) || @canonical_methods[canonical_name]
            yield @sources
          end
          @canonical_methods[canonical_name] = true
          @methods[as] = canonical_name
        end
      end

      def apply(owner, path, line)
        unless @sources.empty?
          @cache.module_eval("# frozen_string_literal: true\n" + @sources.join(";"), path, line)
        end
        @canonical_methods.clear

        @methods.each do |as, canonical_name|
          owner.define_method(as, @cache.instance_method(canonical_name))
        end
      end
    end

    class << self
      def batch(owner, path, line)
        if owner.is_a?(CodeGenerator)
          yield owner
        else
          instance = new(owner, path, line)
          result = yield instance
          instance.execute
          result
        end
      end
    end

    def initialize(owner, path, line)
      @owner = owner
      @path = path
      @line = line
      @namespaces = Hash.new { |h, k| h[k] = MethodSet.new(k) }
    end

    def define_cached_method(canonical_name, namespace:, as: nil, &block)
      @namespaces[namespace].define_cached_method(canonical_name, as: as, &block)
    end

    def execute
      @namespaces.each_value do |method_set|
        method_set.apply(@owner, @path, @line - 1)
      end
    end
  end
end
