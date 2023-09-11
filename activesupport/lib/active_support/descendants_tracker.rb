# frozen_string_literal: true

require "weakref"
require "active_support/ruby_features"

module ActiveSupport
  # = Active Support Descendants Tracker
  #
  # This module provides an internal implementation to track descendants
  # which is faster than iterating through +ObjectSpace+.
  #
  # However Ruby 3.1 provide a fast native +Class#subclasses+ method,
  # so if you know your code won't be executed on older rubies, including
  # +ActiveSupport::DescendantsTracker+ does not provide any benefit.
  module DescendantsTracker
    @clear_disabled = false

    if RUBY_ENGINE == "ruby"
      # On MRI `ObjectSpace::WeakMap` keys are weak references.
      # So we can simply use WeakMap as a `Set`.
      class WeakSet < ObjectSpace::WeakMap # :nodoc:
        alias_method :to_a, :keys

        def <<(object)
          self[object] = true
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

        def <<(object)
          self[object] = true
        end
      end
    end
    @excluded_descendants = WeakSet.new

    module ReloadedClassesFiltering # :nodoc:
      def subclasses
        DescendantsTracker.reject!(super)
      end

      def descendants
        DescendantsTracker.reject!(super)
      end
    end

    class << self
      def disable_clear! # :nodoc:
        unless @clear_disabled
          @clear_disabled = true
          ReloadedClassesFiltering.remove_method(:subclasses)
          ReloadedClassesFiltering.remove_method(:descendants)
          @excluded_descendants = nil
        end
      end

      def clear(classes) # :nodoc:
        raise "DescendantsTracker.clear was disabled because config.enable_reloading is false" if @clear_disabled

        classes.each do |klass|
          @excluded_descendants << klass
          klass.descendants.each do |descendant|
            @excluded_descendants << descendant
          end
        end
      end

      def reject!(classes) # :nodoc:
        if @excluded_descendants
          classes.reject! { |d| @excluded_descendants.include?(d) }
        end
        classes
      end
    end

    if RubyFeatures::CLASS_SUBCLASSES
      class << self
        def subclasses(klass)
          klass.subclasses
        end

        def descendants(klass)
          klass.descendants
        end
      end

      def descendants
        subclasses = DescendantsTracker.reject!(self.subclasses)
        subclasses.concat(subclasses.flat_map(&:descendants))
      end
    else
      # DescendantsArray is an array that contains weak references to classes.
      # Note: DescendantsArray is redundant with WeakSet, however WeakSet when used
      # on Ruby 2.7 or 3.0 can trigger a Ruby crash: https://bugs.ruby-lang.org/issues/18928
      class DescendantsArray # :nodoc:
        include Enumerable

        def initialize
          @refs = []
        end

        def <<(klass)
          @refs << WeakRef.new(klass)
        end

        def each
          @refs.reject! do |ref|
            yield ref.__getobj__
            false
          rescue WeakRef::RefError
            true
          end
          self
        end

        def refs_size
          @refs.size
        end

        def cleanup!
          @refs.delete_if { |ref| !ref.weakref_alive? }
        end

        def reject!
          @refs.reject! do |ref|
            yield ref.__getobj__
          rescue WeakRef::RefError
            true
          end
        end
      end

      @direct_descendants = {}

      class << self
        def subclasses(klass)
          descendants = @direct_descendants[klass]
          descendants ? DescendantsTracker.reject!(descendants.to_a) : []
        end

        def descendants(klass)
          subclasses = self.subclasses(klass)
          subclasses.concat(subclasses.flat_map { |k| descendants(k) })
        end

        # This is the only method that is not thread safe, but is only ever called
        # during the eager loading phase.
        def store_inherited(klass, descendant) # :nodoc:
          (@direct_descendants[klass] ||= DescendantsArray.new) << descendant
        end
      end

      def subclasses
        DescendantsTracker.subclasses(self)
      end

      def descendants
        DescendantsTracker.descendants(self)
      end

      private
        def inherited(base) # :nodoc:
          DescendantsTracker.store_inherited(self, base)
          super
        end
    end
  end
end
