require 'active_support/core_ext/module/anonymous'
require 'active_support/core_ext/module/reachable'

class Class
  if RUBY_ENGINE == 'jruby'
    def descendants # :nodoc:
      JRuby.reference(self).subclasses(true).to_a
    end

    def subclasses
      JRuby.reference(self).subclasses(false).to_a
    end
  else
    def descendants # :nodoc:
      descendants = []
      ObjectSpace.each_object(singleton_class) do |k|
        descendants.unshift k unless k == self
      end
      descendants
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
      subclasses, chain = [], descendants
      chain.each do |k|
	subclasses << k unless chain.any? { |c| c > k }
      end
      subclasses
    end
  end
end
