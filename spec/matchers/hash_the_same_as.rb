module HashTheSameAsMatcher
  class HashTheSameAs
    def initialize(expected)
      @expected = expected
    end
    
    def matches?(target)
      @target = target
      hash = {}
      hash[@expected] = :some_arbitrary_value
      hash[@target] == :some_arbitrary_value
    end
    
    def failure_message
      "expected #{@target} to hash the same as #{@expected}; they must be `eql?` and have the same `#hash` value"
    end
    
    def negative_failure_message
      "expected #{@target} to hash differently than #{@expected}; they must not be `eql?` or have a differing `#hash` values"
    end
  end
  
  def hash_the_same_as(expected)
    HashTheSameAs.new(expected)
  end
end