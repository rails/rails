=begin rdoc

= Ruby on Rails Core Extensions

provides .blank?

=end
unless Object.respond_to?(:blank?) #:nodoc:
  # Check first to see if we are in a Rails environment, no need to 
  # define these methods if we are
  class Object
    # An object is blank if it's nil, empty, or a whitespace string.
    # For example, "", "   ", nil, [], and {} are blank.
    #
    # This simplifies
    #   if !address.nil? && !address.empty?
    # to
    #   if !address.blank?
    def blank?
      if respond_to?(:empty?) && respond_to?(:strip)
        empty? or strip.empty?
      elsif respond_to?(:empty?)
        empty?
      else
        !self
      end
    end
  end

  class NilClass #:nodoc:
    def blank?
      true
    end
  end

  class FalseClass #:nodoc:
    def blank?
      true
    end
  end

  class TrueClass #:nodoc:
    def blank?
      false
    end
  end

  class Array #:nodoc:
    alias_method :blank?, :empty?
  end

  class Hash #:nodoc:
    alias_method :blank?, :empty?
  end

  class String #:nodoc:
    def blank?
      empty? || strip.empty?
    end
  end

  class Numeric #:nodoc:
    def blank?
      false
    end
  end
end