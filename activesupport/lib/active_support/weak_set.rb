# :markup: markdown
# frozen_string_literal: true

module ActiveSupport
  if RUBY_ENGINE == "ruby"
    # On MRI `ObjectSpace::WeakMap` keys are weak references.
    # So we can simply use WeakMap as a `Set`.
    class WeakSet < ObjectSpace::WeakMap # :nodoc:
      alias_method :to_a, :keys
      alias_method :each, :each_key

      def <<(object)
        self[object] = true
      end

      def initialize_copy(other)
        super
        other.each { |object| self << object }
      end
    end
  else
    # On TruffleRuby `ObjectSpace::WeakMap` keys are strong references.
    # So we use `object_id` as a key and the actual object as a value.
    #
    # JRuby for now doesn't have Class#descendant, but when it will, it will likely
    # have the same WeakMap semantic than Truffle so we future proof this as much as possible.
    class WeakSet # :nodoc:
      def initialize
        @map = ObjectSpace::WeakMap.new
      end

      def [](object)
        @map.key?(object.object_id)
      end
      alias_method :include?, :[]

      def []=(object, _present)
        @map[object.object_id] = object
      end

      def to_a
        @map.values
      end

      def each(&block)
        @map.each_value(&block)
      end

      def <<(object)
        self[object] = true
      end

      def initialize_copy(other)
        super
        @map = ObjectSpace::WeakMap.new
        other.each { |object| self << object }
      end
    end
  end
end
