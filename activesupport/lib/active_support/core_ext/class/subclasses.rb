require 'active_support/core_ext/module/anonymous'
require 'active_support/core_ext/module/reachable'

class Class
  begin
    ObjectSpace.each_object(Class.new) {}

    def descendants # :nodoc:
      descendants = []
      ObjectSpace.each_object(singleton_class) do |k|
        descendants.unshift k unless k == self
      end
      descendants
    end
  rescue StandardError # JRuby
    def descendants # :nodoc:
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
