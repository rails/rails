require 'erb'
require 'yaml'
require 'active_record/support/class_inheritable_attributes'
require 'active_record/support/inflector'

# Fixtures are a way of organizing data that you want to test against. You normally have one YAML file with fixture
# definitions per model. They're just hashes of hashes with the first-level key being the name of fixture (try to keep
# that name unique across all fixtures in the system for reasons that will follow). The value to that key is a hash
# where the keys are column names and the values the fixture data you want to insert into it. Example for developers.yml:
#
# david:
#  id: 1
#  name: David Heinemeier Hansson
#  birthday: 1979-10-15
#  profession: Systems development
#
# steve:
#  id: 2
#  name: Steve Ross Kellock
#  birthday: 1974-09-27
#  profession: guy with keyboard
#
# So this YAML file includes two fixtures. T
#
# Now when we call <tt>@developers = Fixtures.create_fixtures(".", "developers")</tt> both developers will get inserted into 
# the "developers" table through the active Active Record connection (that must be setup before-hand). And we can now query 
# the fixture data through the <tt>@developers</tt> hash, so <tt>@developers["david"]["name"]</tt> will return 
# <tt>"David Heinemeier Hansson"</tt> and <tt>@developers["david"]["birthday"]</tt> will return <tt>Date.new(1979, 10, 15)</tt>.
#
# In addition to getting the raw data, we can also get the Developer object by doing @developers["david"].find. This can then 
# be used for comparison in a unit test. Something like:
#
#   def test_find
#     assert_equal @developers["david"]["name"], @developers["david"].find.name
#   end
#
# Comparing that the data we have on the name is also what the object returns when we ask for it.
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
      fixtures = []
      connection.transaction do
        fixtures = table_names.flatten.map do |table_name|
          Fixtures.new(connection, table_name.to_s, File.join(fixtures_directory, table_name.to_s))
        end
        fixtures.reverse.each{ |fixture| fixture.delete_existing_fixtures }
        fixtures.each{ |fixture| fixture.insert_fixtures }
      end
      return fixtures.size > 1 ? fixtures : fixtures.first
    ensure
      ActiveRecord::Base.logger.level = old_logger_level
    end
  end

  def initialize(connection, table_name, fixture_path, file_filter = /^\.|CVS|\.yml/)
    @connection, @table_name, @fixture_path, @file_filter = connection, table_name, fixture_path, file_filter
    @class_name = Inflector.classify(@table_name)

    read_fixture_files
  end

  def delete_existing_fixtures
    @connection.delete "DELETE FROM #{@table_name}"
  end

  def insert_fixtures
    values.each do |fixture|
      @connection.execute "INSERT INTO #{@table_name} (#{fixture.key_list}) VALUES(#{fixture.value_list})"
    end
  end

  private
    def read_fixture_files
      if File.exists?(yaml_file_path)
        YAML::load(erb_render(IO.read(yaml_file_path))).each do |name, data|
          self[name] = Fixture.new(data, @class_name)
        end
      else
        Dir.entries(@fixture_path).each do |file| 
          self[file] = Fixture.new(File.join(@fixture_path, file), @class_name) unless file =~ @file_filter
        end
      end
    end

    def yaml_file_path
      @fixture_path + ".yml"
    end
    
    def yaml_fixtures_key(path)
      File.basename(@fixture_path).split(".").first
    end

    def erb_render(fixture_content)
      ERB.new(fixture_content).result
    end
end

class Fixture #:nodoc:
  include Enumerable
  class FixtureError < StandardError; end
  class FormatError < FixtureError; end

  def initialize(fixture, class_name)
    @fixture = fixture.is_a?(Hash) ? fixture : read_fixture_file(fixture)
    @class_name = class_name
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
    def read_fixture_file(fixture_file_path)
      IO.readlines(fixture_file_path).inject({}) do |fixture, line|
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
