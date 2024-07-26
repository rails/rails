# Fixtures are a way of organizing data that you want to test against. Each fixture file is created as a row
# in the database and created as a hash with column names as keys and data as values. All of these fixture hashes
# are kept in an overall hash where they can be accessed by their file name.
#
# Example:
#
# Directory with the fixture files
#
#   developers/
#     david
#     luke
#     jamis
#
# The file +david+ then contains:
#
#   id => 1
#   name => David Heinemeier Hansson
#   birthday => 1979-10-15
#   profession => Systems development
#
# Now when we call <tt>@developers = Fixtures.new(ActiveRecord::Base.connection, "developers", "developers/")</tt> all three
# developers will get inserted into the "developers" table through the active Active Record connection (that must be setup
# before-hand). And we can now query the fixture data through the <tt>@developers</tt> hash, so <tt>@developers["david"]["name"]</tt>
# will return <tt>"David Heinemeier Hansson"</tt> and <tt>@developers["david"]["birthday"]</tt> will return <tt>Date.new(1979, 10, 15)</tt>.
#
# This can then be used for comparison in a unit test. Something like:
#
#   def test_find
#     assert_equal @developers["david"]["name"], Developer.find(@developers["david"]["id"]).name
#   end
class Fixtures
  def initialize(connection, table_name, fixture_path, file_filter = /^\.|CVS/)
    @connection, @table_name, @fixture_path, @file_filter = connection, table_name, fixture_path, file_filter
    @fixtures = read_fixtures

    delete_existing_fixtures
    insert_fixtures
  end

  # Access a fixture hash by using its file name as the key
  def [](key)
    @fixtures[key]
  end
  
  # Get the number of fixtures kept in this container
  def length
    @fixtures.length
  end

  private
    def read_fixtures
      Dir.entries(@fixture_path).inject({}) do |fixtures, file|
        fixtures[file] = Fixture.new(@fixture_path, file) unless file =~ @file_filter
        fixtures
      end
    end

    def delete_existing_fixtures
      @connection.delete "DELETE FROM #{@table_name}"
    end

    def insert_fixtures
      @fixtures.values.each do |fixture|
        @connection.insert "INSERT INTO #{@table_name} (#{fixture.key_list}) VALUES(#{fixture.value_list})"
      end
    end
  
    def []=(key, value)
      @fixtures[key] = value
    end  
end


class Fixture #:nodoc:
  def initialize(fixture_path, file)
    @fixture_path, @file = fixture_path, file
    @fixture = read_fixture
  end
  
  def [](key)
    @fixture[key]
  end
  
  def to_hash
    @fixture
  end

  def key_list
    @fixture.keys.join(", ")
  end
  
  def value_list
    @fixture.values.map { |v| "'#{v}'" }.join(", ")
  end
  
  private
    def read_fixture
      IO.readlines("#{@fixture_path}/#{@file}").inject({}) do |fixture, line|
        key, value = line.split(/ => /)
        fixture[key.strip] = value.strip
        fixture
      end
    end
end
