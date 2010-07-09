require 'active_support/core_ext/module/anonymous'
require 'active_support/core_ext/module/reachable'

class Class #:nodoc:
  # Rubinius
  if defined?(Class.__subclasses__)
    alias :subclasses :__subclasses__

    def descendants
      descendants = []
      __subclasses__.each do |k|
        descendants << k
        descendants.concat k.descendants
      end
      descendants
    end
  else # MRI
    begin
      ObjectSpace.each_object(Class.new) {}

      def descendants
        descendants = []
        ObjectSpace.each_object(class << self; self; end) do |k|
          descendants.unshift k unless k == self
        end
        descendants
      end
    rescue StandardError # JRuby
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
    #   Integer.subclasses # => [Bignum, Fixnum]
    def subclasses
      subclasses, chain = [], descendants
      chain.each do |k|
        subclasses << k unless chain.any? { |c| c > k }
      end
      subclasses
    end
  end
end
