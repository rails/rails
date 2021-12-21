# frozen_string_literal: true

require "active_support/ruby_features"

class Class
  # Returns an array with all classes that are < than its receiver.
  #
  #   class C; end
  #   C.descendants # => []
  #
  #   class B < C; end
  #   C.descendants # => [B]
  #
  #   class A < B; end
  #   C.descendants # => [B, A]
  #
  #   class D < C; end
  #   C.descendants # => [B, A, D]
  def descendants
    ObjectSpace.each_object(singleton_class).reject do |k|
      k.singleton_class? || k == self
    end
  end unless ActiveSupport::RubyFeatures::CLASS_SUBCLASSES

  # Returns an array with the direct children of +self+.
  #
  #   class Foo; end
  #   class Bar < Foo; end
  #   class Baz < Bar; end
  #
  #   Foo.subclasses # => [Bar]
  def subclasses
    descendants.select { |descendant| descendant.superclass == self }
  end unless ActiveSupport::RubyFeatures::CLASS_SUBCLASSES
end
