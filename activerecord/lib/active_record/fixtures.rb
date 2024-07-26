require 'yaml'

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
#
# == YAML fixtures
#
# Additionally, fixtures supports yaml files.  Like fixture files, these yaml files have a pre-defined format.  The document
# must be formatted like this:
#
# name: david
# data:
#  id: 1
#  name: David Heinemeier Hansson
#  birthday: 1979-10-15
#  profession: Systems development
# ---
# name: steve
# data:
#  id: 2
#  name: Steve Ross Kellock
#  birthday: 1974-09-27
#  profession: guy with keyboard
#
# In that file, there's two records.  Each record must have two parts:  'name' and 'data'.  The data that you add
# must be indented like you see above.
#
# Yaml fixtures file names must end with .yaml as in people.yaml or camel.yaml.  The yaml fixtures are placed in the same
# directory as the normal fixtures and can happy co-exist.  :)
class Fixtures
  def self.create_fixtures(fixtures_directory, *table_names)
    connection = block_given? ? yield : ActiveRecord::Base.connection
    ActiveRecord::Base.logger.level = Logger::ERROR

    fixtures = [ table_names ].flatten.collect do |table_name|
      Fixtures.new(connection, table_name, "#{fixtures_directory}/#{table_name}")
    end

    ActiveRecord::Base.logger.level = Logger::DEBUG

    return fixtures.size > 1 ? fixtures : fixtures.first
  end

  def initialize(connection, table_name, fixture_path, file_filter = /^\.|CVS|\.yaml/)
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
        # is this a regular fixture file?
        fixtures[file] = Fixture.new(@fixture_path, file) unless file =~ @file_filter
        # is this a *.yaml file?
        if file =~ /\.yaml/
          YamlFixture.produce( "#{@fixture_path}/#{file}" ).each { |fix| fixtures[fix.yaml_name] = fix }
        end
        fixtures
      end
    end

    def delete_existing_fixtures
      @connection.delete "DELETE FROM #{@table_name}"
    end

    def insert_fixtures
      @fixtures.values.each do |fixture|
        @connection.execute "INSERT INTO #{@table_name} (#{fixture.key_list}) VALUES(#{fixture.value_list})"
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

# A YamlFixture is like a fixture, but instead of a name to use as
# a key, it uses a yaml_name.
class YamlFixture < Fixture #:nodoc:
  # yaml_name is equivalent to a normal fixture's filename
  attr_accessor :yaml_name

  # constructor is passed the name & the actual instantiate fixture
  def initialize(yaml_name, fixture)
    @yaml_name, @fixture = yaml_name, fixture
  end

  # given a valid yaml file name, create an array of YamlFixture objects
  def self.produce( yaml_file_name )
    results = []
    yaml_file = File.open( yaml_file_name )
    YAML::load_documents( yaml_file ) do |doc|
      f = YamlFixture.new( doc['name'], doc['data'] )
      results << f
    end
    yaml_file.close
    results
  end
end
