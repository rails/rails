class Symbol
  # Turns the symbol into a simple proc, which is especially useful for enumerations. Examples:
  #
  #   # The same as people.collect { |p| p.name }
  #   people.collect(&:name)
  #
  #   # The same as people.select { |p| p.manager? }.collect { |p| p.salary }
  #   people.select(&:manager?).collect(&:salary)
  def to_proc
    Proc.new { |obj, *args| obj.send(self, *args) }
  end
end
