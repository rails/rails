require 'abstract_unit'
require 'fixtures/default'
require 'fixtures/post'
require 'fixtures/task'

class SqlServerAdapterTest < Test::Unit::TestCase
  fixtures :posts, :tasks

  def setup
    @connection = ActiveRecord::Base.connection
  end

  def teardown
    @connection.execute("SET LANGUAGE us_english")
  end

  # SQL Server 2000 has a bug where some unambiguous date formats are not 
  # correctly identified if the session language is set to german
  def test_date_insertion_when_language_is_german
    @connection.execute("SET LANGUAGE deutsch")

    assert_nothing_raised do
      Task.create(:starting => Time.utc(2000, 1, 31, 5, 42, 0), :ending => Date.new(2006, 12, 31))
    end
  end

  def test_execute_without_block_closes_statement
    assert_all_statements_used_are_closed do
      @connection.execute("SELECT 1")
    end
  end
  
  def test_execute_with_block_closes_statement
    assert_all_statements_used_are_closed do
      @connection.execute("SELECT 1") do |sth|
        assert !sth.finished?, "Statement should still be alive within block"
      end
    end
  end
  
  def test_insert_with_identity_closes_statement
    assert_all_statements_used_are_closed do
      @connection.insert("INSERT INTO accounts ([id], [firm_id],[credit_limit]) values (999, 1, 50)")
    end
  end
  
  def test_insert_without_identity_closes_statement
    assert_all_statements_used_are_closed do
      @connection.insert("INSERT INTO accounts ([firm_id],[credit_limit]) values (1, 50)")
    end
  end
  
  def test_active_closes_statement
    assert_all_statements_used_are_closed do
      @connection.active?
    end
  end 

  def assert_all_statements_used_are_closed(&block)
    existing_handles = []
    ObjectSpace.each_object(DBI::StatementHandle) {|handle| existing_handles << handle}
    GC.disable
    
    yield
    
    used_handles = []
    ObjectSpace.each_object(DBI::StatementHandle) {|handle| used_handles << handle unless existing_handles.include? handle}
         
    assert_block "No statements were used within given block" do
      used_handles.size > 0
    end
    
    ObjectSpace.each_object(DBI::StatementHandle) do |handle|
      assert_block "Statement should have been closed within given block" do 
        handle.finished?
      end      
    end
  ensure
    GC.enable
  end
end
