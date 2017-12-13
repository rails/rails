# frozen_string_literal: true

require "concurrent/map"

module ActiveModel
  class AttributeMethodsBuilder < Module # :nodoc:
    NAME_COMPILABLE_REGEXP = /\A[a-zA-Z_]\w*[!?=]?\z/
    CALL_COMPILABLE_REGEXP = /\A[a-zA-Z_]\w*[!?]?\z/

    attr_accessor :matchers

    def initialize
      @matchers = [AttributeMethodMatcher.new]
      @method_names = Set.new
      # Strictly-speaking this is not necessary, since AM::AttributeMethods
      # includes the module, and AR::AttributeMethods includes
      # AM::AttributeMethods. However, since this class depends on methods in
      # it, we should ensure that it is included into any module that includes
      # instances of the builder.
      include AttributeMissingMethods
    end

    def prefix(*prefixes)
      self.matchers += prefixes.map! { |prefix| AttributeMethodMatcher.new prefix: prefix }
      undefine_attribute_methods
    end

    def suffix(*suffixes)
      self.matchers += suffixes.map! { |suffix| AttributeMethodMatcher.new suffix: suffix }
      undefine_attribute_methods
    end

    def affix(*affixes)
      self.matchers += affixes.map! { |affix| AttributeMethodMatcher.new prefix: affix[:prefix], suffix: affix[:suffix] }
      undefine_attribute_methods
    end

    def define_attribute_methods(*attr_names)
      attr_names.each { |attr_name| define_attribute_method(attr_name) }
    end

    def define_attribute_method(attr_name)
      matchers.each do |matcher|
        method_name = matcher.method_name(attr_name)
        @method_names << method_name.to_sym

        unless instance_method_already_implemented?(method_name)
          generate_method = "define_method_#{matcher.method_missing_target}"

          if respond_to?(generate_method, true)
            send(generate_method, attr_name.to_s)
          else
            define_proxy_call true, method_name, matcher.method_missing_target, attr_name.to_s
          end
        end
      end
      matchers_cache.clear
    end

    def undefine_attribute_methods
      (@method_names & instance_methods(false)).each(&method(:undef_method))
      @method_names.clear
      matchers_cache.clear
    end

    def alias_attribute(new_name, old_name)
      matchers.each do |matcher|
        define_proxy_call false, matcher.method_name(new_name), matcher.method_name(old_name)
      end
    end

    # Check if method name matches any of our attribute method matchers.
    def match(method_name)
      return [] if method_name == "attributes"
      matchers_cache.compute_if_absent(method_name) do
        # Must try to match prefixes/suffixes first, or else the matcher with no prefix/suffix
        # will match every time.
        matchers.partition(&:plain?).reverse.flatten(1).map do |matcher|
          matcher.match(method_name)
        end.compact
      end
    end

    # Includes self into class. Can be overridden to do something different,
    # see ActiveRecord::AttributeMethodsBuilder.
    def apply(klass)
      klass.include self
    end

    # Defines +method_missing+ and +respond_to+ to respond to attribute method
    # calls that match our matchers.
    def define_method_missing
      return false if method_defined?(:method_missing)
      builder = self

      # Allows access to the object attributes, which are held in the hash
      # returned by <tt>attributes</tt>, as though they were first-class
      # methods. So a +Person+ class with a +name+ attribute can for example use
      # <tt>Person#name</tt> and <tt>Person#name=</tt> and never directly use
      # the attributes hash -- except for multiple assignments with
      # <tt>ActiveRecord::Base#attributes=</tt>.
      #
      # It's also possible to instantiate related objects, so a <tt>Client</tt>
      # class belonging to the +clients+ table with a +master_id+ foreign key
      # can instantiate master through <tt>Client#master</tt>.
      define_method :method_missing do |method_name, *arguments, &method_block|
        match = builder.match(method_name.to_s).find { |m| attribute_method?(m.attr_name) }
        if match && !respond_to_without_attributes?(method_name, true)
          attribute_missing(match, *arguments, &method_block)
        else
          super(method_name, *arguments, &method_block)
        end
      end

      define_method :respond_to? do |method_name, include_private_methods = false|
        return true if super(method_name, include_private_methods)

        if builder.match(method_name.to_s).find { |m| attribute_method?(m.attr_name) }
          include_private_methods || !respond_to_without_attributes?(method_name, true)
        else
          false
        end
      end
    end

    private

      # The methods +method_missing+ and +respond_to?+ of this module are
      # invoked often in a typical rails, both of which invoke the method
      # +matched_attribute_method+. The latter method iterates through an
      # array doing regular expression matches, which results in a lot of
      # object creations. Most of the time it returns a +nil+ match. As the
      # match result is always the same given a +method_name+, this cache is
      # used to alleviate the GC, which ultimately also speeds up the app
      # significantly (in our case our test suite finishes 10% faster with
      # this cache).
      def matchers_cache
        @matchers_cache ||= Concurrent::Map.new(initial_capacity: 4)
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

      class AttributeMethodMatcher #:nodoc:
        attr_reader :prefix, :suffix, :method_missing_target

        AttributeMethodMatch = Struct.new(:target, :attr_name, :method_name)

        def initialize(options = {})
          @prefix, @suffix = options.fetch(:prefix, ""), options.fetch(:suffix, "")
          @regex = /^(?:#{Regexp.escape(@prefix)})(.*)(?:#{Regexp.escape(@suffix)})$/
          @method_missing_target = "#{@prefix}attribute#{@suffix}"
          @method_name = "#{prefix}%s#{suffix}"
        end

        def match(method_name)
          if @regex =~ method_name
            AttributeMethodMatch.new(method_missing_target, $1, method_name)
          end
        end

        def method_name(attr_name)
          @method_name % attr_name
        end

        def plain?
          prefix.empty? && suffix.empty?
        end
      end

      module AttributeMissingMethods
        # +attribute_missing+ is like +method_missing+, but for attributes. When
        # +method_missing+ is called we check to see if there is a matching
        # attribute method. If so, we tell +attribute_missing+ to dispatch the
        # attribute. This method can be overloaded to customize the behavior.
        def attribute_missing(match, *args, &block)
          __send__(match.target, match.attr_name, *args, &block)
        end

        # A +Person+ instance with a +name+ attribute can ask
        # <tt>person.respond_to?(:name)</tt>, <tt>person.respond_to?(:name=)</tt>,
        # and <tt>person.respond_to?(:name?)</tt> which will all return +true+.
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
