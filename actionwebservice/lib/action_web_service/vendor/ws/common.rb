module WS
  class WSError < StandardError
  end

  def self.derived_from?(ancestor, child)
    child.ancestors.include?(ancestor)
  end
end
