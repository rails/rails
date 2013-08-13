require 'active_support/core_ext/module/anonymous'
require 'active_support/core_ext/module/reachable'

class Class
  begin
    ObjectSpace.each_object(Class.new) {}

    def descendants # :nodoc:
      ObjectSpace.each_object(singleton_class).reject do |k|
        k == self
      end
    end
  rescue # JRuby 1.6 raises a NameError and JRuby 1.7 a RuntimeError.
    def descendants # :nodoc:
      ObjectSpace.each_object(Class).select do |k|
        k < self
      end.uniq
    end
  end

  # Returns an array with the direct children of +self+.
  #
  #   Integer.subclasses # => [Fixnum, Bignum]
  #
  #   class Foo; end
  #   class Bar < Foo; end
  #   class Baz < Bar; end
  #
  #   Foo.subclasses # => [Bar]
  def subclasses
    chain = descendants
    chain.delete_if do |k|
      chain.any? { |c| c > k }
    end
  end
end
