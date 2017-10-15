# frozen_string_literal: true

require "concurrent/map"

module ActiveModel
  class AttributeMethodMatcher < Module
    NAME_COMPILABLE_REGEXP = /\A[a-zA-Z_]\w*[!?=]?\z/
    CALL_COMPILABLE_REGEXP = /\A[a-zA-Z_]\w*[!?]?\z/

    attr_reader :prefix, :suffix, :method_missing_target, :method_names
    AttributeMethodMatch = Struct.new(:target, :attr_name, :method_name)

    def initialize(options = {})
      @prefix, @suffix = options.fetch(:prefix, ""), options.fetch(:suffix, "")
      @regex = /^(?:#{Regexp.escape(@prefix)})(.*)(?:#{Regexp.escape(@suffix)})$/
      @method_missing_target = "#{@prefix}attribute#{@suffix}"
      @method_name = "#{prefix}%s#{suffix}"
      @method_names = []
      define_method_missing
    end

    def included(model_class)
      model_class.include AttributeMissingMethods
    end

    def inspect
      "<#{self.class.name}: #{@regex.inspect}>"
    end

    def define_attribute_methods(*attr_names)
      attr_names.each { |attr_name| define_attribute_method(attr_name) }
    end

    def define_attribute_method(attr_name)
      name = method_name(attr_name)
      unless instance_method_already_implemented?(name)
        generate_method = "define_method_#{method_missing_target}"

        if respond_to?(generate_method, true)
          send(generate_method, attr_name.to_s)
        else
          method_names << name.to_sym
          define_proxy_call true, name, method_missing_target, attr_name.to_s
        end
      end
    end

    def undefine_attribute_methods
      (method_names & instance_methods(false)).each(&method(:undef_method))
      method_names.clear
      matchers_cache.clear
    end

    def alias_attribute(new_name, old_name)
      define_proxy_call false, method_name(new_name), method_name(old_name)
    end

    def match(method_name)
      matchers_cache.compute_if_absent(method_name) do
        if (@regex =~ method_name) && (method_name != :attributes)
          AttributeMethodMatch.new(method_missing_target, $1, method_name.to_s)
        end
      end
    end

    def apply(klass)
      klass.include self
    end

    private
      def define_method_missing
        matcher = self

        define_method :method_missing do |method_name, *arguments, &method_block|
          if (match = matcher.match(method_name.to_s)) &&
              method_name != :attributes &&
              attribute_method?(match.attr_name) &&
              !respond_to_without_attributes?(method_name, true)
            attribute_missing(match, *arguments, &method_block)
          else
            super(method_name, *arguments, &method_block)
          end
        end

        define_method :respond_to? do |method_name, include_private_methods = false|
          if super(method_name, include_private_methods)
            true
          elsif !include_private_methods && super(method_name, true)
            false
          else
            (match = matcher.match(method_name.to_s)) &&
              (method_name != :attributes) &&
              attribute_method?(match.attr_name) || false
          end
        end
      end

      def matchers_cache
        @matchers_cache ||= Concurrent::Map.new(initial_capacity: 4)
      end

      def method_name(attr_name)
        @method_name % attr_name
      end

      def define_proxy_call(include_private, name, send, *extra)
        defn = if NAME_COMPILABLE_REGEXP.match?(name)
          "def #{name}(*args)"
        else
          "define_method(:'#{name}') do |*args|"
        end

        extra = (extra.map!(&:inspect) << "*args").join(", ".freeze)

        target = if CALL_COMPILABLE_REGEXP.match?(send)
          "#{"self." unless include_private}#{send}(#{extra})"
        else
          "send(:'#{send}', #{extra})"
        end

        module_eval <<-RUBY, __FILE__, __LINE__ + 1
          #{defn}
            #{target}
          end
        RUBY
      end

      def instance_method_already_implemented?(method_name)
        method_defined?(method_name)
      end

      module AttributeMissingMethods
        # +attribute_missing+ is like +method_missing+, but for attributes. When
        # +method_missing+ is called we check to see if there is a matching
        # attribute method. If so, we tell +attribute_missing+ to dispatch the
        # attribute. This method can be overloaded to customize the behavior.
        def attribute_missing(match, *args, &block)
          __send__(match.target, match.attr_name, *args, &block)
        end

        alias :respond_to_without_attributes? :respond_to?

        private
          def attribute_method?(attr_name)
            respond_to_without_attributes?(:attributes) && attributes.include?(attr_name)
          end

          def missing_attribute(attr_name, stack)
            raise ActiveModel::MissingAttributeError, "missing attribute: #{attr_name}", stack
          end

          def _read_attribute(attr)
            __send__(attr)
          end
      end
  end
end
