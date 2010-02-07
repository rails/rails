#:stopdoc:
unless Object.respond_to?(:blank?)
  class Object
    # Check first to see if we are in a Rails environment, no need to 
    # define these methods if we are

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

  class NilClass
    def blank?
      true
    end
  end

  class FalseClass
    def blank?
      true
    end
  end

  class TrueClass
    def blank?
      false
    end
  end

  class Array
    alias_method :blank?, :empty?
  end

  class Hash
    alias_method :blank?, :empty?
  end

  class String
    def blank?
      empty? || strip.empty?
    end
  end

  class Numeric
    def blank?
      false
    end
  end
end
#:startdoc: