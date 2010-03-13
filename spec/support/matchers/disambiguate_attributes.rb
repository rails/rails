module Matchers
  class DisambiguateAttributes
    def initialize(attributes)
      @attributes = attributes
    end

    def matches?(actual)
      @actual = actual
      attribute1, attribute2 = @attributes
      @actual[attribute1].descends_from?(attribute1) &&
        !@actual[attribute1].descends_from?(attribute2) &&
        @actual[attribute2].descends_from?(attribute2)
    end

    def failure_message
      ""
      # "expected #{@actual} to disambiguate its attributes"
    end

    def negative_failure_message
      "expected #{@actual} to not disambiguate its attributes"
    end
  end

  def disambiguate_attributes(*attributes)
    DisambiguateAttributes.new(attributes)
  end
end
