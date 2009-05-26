class Symbol
  # Turns the symbol into a simple proc, which is especially useful for enumerations. Examples:
  #
  #   # The same as people.collect { |p| p.name }
  #   people.collect(&:name)
  #
  #   # The same as people.select { |p| p.manager? }.collect { |p| p.salary }
  #   people.select(&:manager?).collect(&:salary)
  #
  # This is a builtin method in Ruby 1.8.7 and later.
  def to_proc
    Proc.new { |*args| args.shift.__send__(self, *args) }
  end unless :to_proc.respond_to?(:to_proc)
end
