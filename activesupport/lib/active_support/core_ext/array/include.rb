class Array
  def include(item)
    self << item unless self.include?(item)
    self
  end
end
