module BeLikeMatcher
  class BeLike
    def initialize(expected)
      @expected = expected
    end
    
    def matches?(target)
      @target = target
      @expected.gsub(/\s+/, ' ').strip == @target.gsub(/\s+/, ' ').strip
    end
    
    def failure_message
      "expected #{@target} to be like #{@expected}"
    end
    
    def negative_failure_message
      "expected #{@target} to be unlike #{@expected}"
    end
  end
  
  def be_like(expected)
    BeLike.new(expected)
  end
end