# Remove 1.8.7's incompatible method.
if :to_proc.respond_to?(:to_proc) && [1] != ([[1, 2]].map(&:first) rescue false)
  class Symbol
    remove_method :to_proc
  end
end

unless :to_proc.respond_to?(:to_proc)
  class Symbol
    # Turns the symbol into a simple proc, which is especially useful for enumerations. Examples:
    #
    #   # The same as people.collect { |p| p.name }
    #   people.collect(&:name)
    #
    #   # The same as people.select { |p| p.manager? }.collect { |p| p.salary }
    #   people.select(&:manager?).collect(&:salary)
    def to_proc
      Proc.new { |*args| args.shift.__send__(self, *args) }
    end
  end
end
