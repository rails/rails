module SqlBuilder
  def connection
    ActiveRecord::Base.connection
  end
  
  delegate :quote_table_name, :quote_column_name, :quote, :to => :connection
end