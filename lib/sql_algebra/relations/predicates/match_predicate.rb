class MatchPredicate < Predicate
  attr_reader :attribute, :regexp
  
  def initialize(attribute, regexp)
    @attribute, @regexp = attribute, regexp
  end
end