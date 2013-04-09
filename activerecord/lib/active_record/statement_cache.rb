module ActiveRecord	

  # Statement cache is used to cache a single statement in order to avoid creating the AST again.
  # 
  # Initializing the cache is done by passing the statement in the initialization block:
  #
  # cache = ActiveRecord::StatementCache.new do
  #   Book.where(:name => "my book").limit(100)
  # end
  # 
  # The cached statement is executed by using the execute method
  # 
  # cache.execute
  #
  # The relation returned by the yield is cached and duped for the following executions, then loaded by calling to_a.
  class StatementCache 
    def initialize
      @relation = yield
    end
 
    def execute
      @relation.dup.to_a
    end
  end
end
