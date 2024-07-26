require 'yaml'
require 'active_record/support/class_inheritable_attributes'
require 'active_record/support/inflector'

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
# == Automatic fixture setup and instance variable availability
#
# Fixtures can also be automatically instantiated in instance variables relating to their names using the following style:
#
#   class FixturesTest < Test::Unit::TestCase
#     fixtures :developers # you can add more with comma separation
#
#     def test_developers
#       assert_equal 3, @developers.size # the container for all the fixtures is automatically set
#       assert_kind_of Developer, @david # works like @developers["david"].find
#       assert_equal "David Heinemeier Hansson", @david.name
#     end
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
# Yaml fixtures file names must end with .yml as in people.yml or camel.yml.  The yaml fixtures are placed in the same
# directory as the normal fixtures and can happy co-exist.  :)
class Fixtures < Hash
  def self.instantiate_fixtures(object, fixtures_directory, *table_names)
    [ create_fixtures(fixtures_directory, *table_names) ].flatten.each_with_index do |fixtures, idx|
      object.instance_variable_set "@#{table_names[idx]}", fixtures
      fixtures.each { |name, fixture| object.instance_variable_set "@#{name}", fixture.find }
    end
  end
  
  def self.create_fixtures(fixtures_directory, *table_names)
    connection = block_given? ? yield : ActiveRecord::Base.connection
    old_logger_level = ActiveRecord::Base.logger.level

    begin
      ActiveRecord::Base.logger.level = Logger::ERROR
      fixtures = connection.transaction do
        table_names.flatten.map do |table_name|
          Fixtures.new(connection, table_name.to_s, File.join(fixtures_directory, table_name.to_s))
        end
      end
      return fixtures.size > 1 ? fixtures : fixtures.first
    ensure
      ActiveRecord::Base.logger.level = old_logger_level
    end
  end

  def initialize(connection, table_name, fixture_path, file_filter = /^\.|CVS|\.yaml/)
    @connection, @table_name, @fixture_path, @file_filter = connection, table_name, fixture_path, file_filter
    @class_name = Inflector.classify(@table_name)

    read_fixture_files
    delete_existing_fixtures
    insert_fixtures
  end

  private
    def read_fixture_files
      Dir.entries(@fixture_path).each do |file|
        case file
          when /\.ya?ml$/
            path = File.join(@fixture_path, file)
            YamlFixture.produce(path).each { |fixture|
                self[fixture.yaml_name] = fixture
            }
          when @file_filter
            # skip
          else
            self[file] = Fixture.new(@fixture_path, file, @class_name)
        end
      end
    end

    def delete_existing_fixtures
      @connection.delete "DELETE FROM #{@table_name}"
    end

    def insert_fixtures
      values.each do |fixture|
        @connection.execute "INSERT INTO #{@table_name} (#{fixture.key_list}) VALUES(#{fixture.value_list})"
      end
    end
end

class Fixture #:nodoc:
  include Enumerable
  class FixtureError < StandardError; end
  class FormatError < FixtureError; end

  def initialize(fixture_path, file, class_name)
    @fixture_path, @file, @class_name = fixture_path, file, class_name
    @fixture = read_fixture_file
    @class_name
  end

  def each
    @fixture.each { |item| yield item }
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
    @fixture.values.map { |v| ActiveRecord::Base.connection.quote(v).gsub('\\n', "\n").gsub('\\r', "\r") }.join(", ")
  end
  
  def find
    Object.const_get(@class_name).find(self["id"])
  end
  
  private
    def read_fixture_file
      path = File.join(@fixture_path, @file)
      IO.readlines(path).inject({}) do |fixture, line|
        # Mercifully skip empty lines.
        next if line.empty?

        # Use the same regular expression for attributes as Active Record.
        unless md = /^\s*([a-zA-Z][-_\w]*)\s*=>\s*(.+)\s*$/.match(line)
          raise FormatError, "#{path}: fixture format error at '#{line}'.  Expecting 'key => value'."
        end
        key, value = md.captures

        # Disallow duplicate keys to catch typos.
        raise FormatError, "#{path}: duplicate '#{key}' in fixture." if fixture[key]
        fixture[key] = value.strip
        fixture
      end
    end
end

# A YamlFixture is like a fixture, but instead of a name to use as
# a key, it uses a yaml_name.
class YamlFixture < Fixture #:nodoc:
  class YamlFormatError < FormatError; end

  # yaml_name is analogous to a normal fixture's filename
  attr_reader :yaml_name

  # Instantiate with fixture name and data.
  def initialize(yaml_name, fixture)
    @yaml_name, @fixture = yaml_name, fixture
  end

  def produce(yaml_file_name)
    YamlFixture.produce(yaml_file_name)
  end

  # Extract an array of YamlFixtures from a yaml file.
  def self.produce(yaml_file_name)
    fixtures = []
    File.open(yaml_file_name) do |yaml_file|
      YAML::load_documents(yaml_file) do |doc|
        missing = %w(name data).reject { |key| doc[key] }.join(' and ')
        raise YamlFormatError, "#{path}: yaml fixture missing #{missing}: #{doc.to_yaml}" unless missing.empty?
        fixtures << YamlFixture.new(doc['name'], doc['data'])
      end
    end
    fixtures
  end
end

class Test::Unit::TestCase #:nodoc:
  include ClassInheritableAttributes
  
  cattr_accessor :fixture_path
  cattr_accessor :fixture_table_names
  
  def self.fixtures(*table_names)
    write_inheritable_attribute("fixture_table_names", table_names)
  end

  def setup
    instantiate_fixtures(*fixture_table_names) if fixture_table_names
  end
  
  def self.method_added(method_symbol)
    if method_symbol == :setup && !method_defined?(:setup_without_fixtures)
      alias_method :setup_without_fixtures, :setup
      define_method(:setup) do
        instantiate_fixtures(*fixture_table_names) if fixture_table_names
        setup_without_fixtures
      end
    end
  end

  private
    def instantiate_fixtures(*table_names)
      Fixtures.instantiate_fixtures(self, fixture_path, *table_names)
    end
    
    def fixture_table_names
      self.class.read_inheritable_attribute("fixture_table_names")
    end
end