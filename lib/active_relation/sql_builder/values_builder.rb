class ValuesBuilder < SqlBuilder
  def initialize(&block)
    @values = []
    super(&block)
  end
  
  def row(*values)
    @values << "(#{values.collect { |v| quote(v) }.join(', ')})"
  end
      
  def to_s
    @values.join(', ')
  end
  
  delegate :blank?, :to => :@values
end