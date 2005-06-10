require 'abstract_unit'
require 'fixtures/topic'

class ThreadSafetyTest < Test::Unit::TestCase
  self.use_transactional_fixtures = false

  fixtures :topics

  def setup
    @threads = []
  end
  
  def test_threading_on_transactions
    # SQLite breaks down under thread banging
    # Jamis Buck (author of SQLite-ruby): "I know that sqlite itself is not designed for concurrent access"
    if ActiveRecord::ConnectionAdapters.const_defined? :SQLiteAdapter
      return true if ActiveRecord::Base.connection.instance_of?(ActiveRecord::ConnectionAdapters::SQLiteAdapter)
    end

    5.times do |thread_number|
      @threads << Thread.new(thread_number) do |thread_number|
        first, second = Topic.find(1, 2)
        Topic.transaction(first, second) do
          Topic.logger.info "started #{thread_number}"
          first.approved  = 1
          second.approved = 0
          first.save
          second.save
          Topic.logger.info "ended #{thread_number}"
        end
      end
    end
    
    @threads.each { |t| t.join }
  end
end
