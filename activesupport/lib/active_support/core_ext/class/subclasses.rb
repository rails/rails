require "active_support/core_ext/module/anonymous"
require "active_support/core_ext/module/reachable"

class Class
  begin
    # Test if this Ruby supports each_object against singleton_class
    ObjectSpace.each_object(Numeric.singleton_class) {}

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
      descendants = []
      ObjectSpace.each_object(singleton_class) do |k|
        next if k.singleton_class?
        descendants.unshift k unless k == self
      end
      descendants
    end
  rescue StandardError # JRuby 9.0.4.0 and earlier
    def descendants
      descendants = []
      ObjectSpace.each_object(Class) do |k|
        descendants.unshift k if k < self
      end
      descendants.uniq!
      descendants
    end
  end

  # Returns an array with the direct children of +self+.
  #
  #   class Foo; end
  #   class Bar < Foo; end
  #   class Baz < Bar; end
  #
  #   Foo.subclasses # => [Bar]
  def subclasses
    subclasses, chain = [], descendants
    chain.each do |k|
      subclasses << k unless chain.any? { |c| c > k }
    end
    subclasses
  end
end
