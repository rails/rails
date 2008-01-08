class SqlBuilder
  def initialize(&block)
    @callers = []
    call(&block) if block
  end
  
  def method_missing(method, *args)
    @callers.last.send(method, *args)
  end
  
  def ==(other)
    to_s == other.to_s
  end
  
  def to_s
  end
  
  def call(&block)
    returning self do |builder|
      @callers << eval("self", block.binding)
      begin
        instance_eval &block
      ensure
        @callers.pop
      end
    end
  end
  
  private
  delegate :quote_table_name, :quote_column_name, :quote, :to => :connection
  
  def connection
    ActiveRecord::Base.connection
  end
end