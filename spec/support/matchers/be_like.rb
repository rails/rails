module Matchers
  class BeLike
    def initialize(expected)
      @expected = expected.gsub(/\s+/, ' ').strip
    end

    def matches?(actual)
      @actual = actual.gsub(/\s+/, ' ').strip
      @expected == @actual
    end

    def failure_message
      "expected\n#{@actual}\nto be like\n#{@expected}"
    end

    def negative_failure_message
      "expected\n#{@actual}\nto be unlike\n#{@expected}"
    end
  end

  def be_like(expected)
    BeLike.new(expected)
  end
end
