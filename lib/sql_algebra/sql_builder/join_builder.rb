class JoinBuilder < SqlBuilder
  def initialize(table, &block)
    @table = table
    @conditions = ConditionsBuilder.new
    super(&block)
  end
  
  delegate :call, :to => :@conditions
  
  def to_s
    "#{join_type} #{@table} ON #{@conditions}"
  end
end