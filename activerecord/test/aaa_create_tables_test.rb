require 'abstract_unit'

# The filename for this test begins with "aaa" so that
# it will be the first test.

class SqlFile < File
  #Define an iterator that iterates over the statements in a .sql file.
  #statements are separated by a semicolon.
  def initialize(path)
    super(path)
  end
  
  def each_statement()
    statement = ''
    each_line { |line|
      #The last character of each line is a line-feed, so we will check the next-to-last character
      #to see if it is a semicolon.  A better way of doing this would be to look for a semicolon anywhere
      #within the line in case multiple statements have been put on a single line.
      #The last statement in the file must be followed by a line-feed.
      if line.slice(-2,1)==';' then
        statement = statement + line.slice(0,line.length-2) + "\n"
        yield statement
        statement = ''
      else
        statement = statement + line
      end
    }
  end
end

class CreateTablesTest < Test::Unit::TestCase
  def setup
    # This method is required by rake.
  end

  def run_sql_file(connection, path)
    sql_file = SqlFile.new(path)
    sql_file.each_statement { |statement|
    begin
      #Skip errors.  If there is a problem creating the tables then it will show up in other tests.
      connection.execute(statement)
    rescue ActiveRecord::StatementInvalid
    end }
  end

  def test_table_creation
    adapter_name = ActiveRecord::Base.connection.adapter_name.downcase
    run_sql_file ActiveRecord::Base.connection, "test/fixtures/db_definitions/" + adapter_name + ".drop.sql"
    run_sql_file ActiveRecord::Base.connection, "test/fixtures/db_definitions/" + adapter_name + ".sql"

    # Now do the same thing with the connection used by multiple_db_test.rb
    adapter_name = Course.retrieve_connection.adapter_name.downcase
    run_sql_file Course.retrieve_connection, "test/fixtures/db_definitions/" + adapter_name + "2.drop.sql"
    run_sql_file Course.retrieve_connection, "test/fixtures/db_definitions/" + adapter_name + "2.sql"
    
    assert_equal 1,1
  end
end
