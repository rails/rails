require 'erb'

begin
  require 'psych'
rescue LoadError
end

require 'yaml'
require 'zlib'
require 'active_support/dependencies'
require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/logger'
require 'active_support/ordered_hash'
require 'active_record/fixtures/file'

if defined? ActiveRecord
  class FixtureClassNotFound < ActiveRecord::ActiveRecordError #:nodoc:
  end
else
  class FixtureClassNotFound < StandardError #:nodoc:
  end
end

module ActiveRecord
  # \Fixtures are a way of organizing data that you want to test against; in short, sample data.
  #
  # They are stored in YAML files, one file per model, which are placed in the directory
  # appointed by <tt>ActiveSupport::TestCase.fixture_path=(path)</tt> (this is automatically
  # configured for Rails, so you can just put your files in <tt><your-rails-app>/test/fixtures/</tt>).
  # The fixture file ends with the <tt>.yml</tt> file extension (Rails example:
  # <tt><your-rails-app>/test/fixtures/web_sites.yml</tt>). The format of a fixture file looks
  # like this:
  #
  #   rubyonrails:
  #     id: 1
  #     name: Ruby on Rails
  #     url: http://www.rubyonrails.org
  #
  #   google:
  #     id: 2
  #     name: Google
  #     url: http://www.google.com
  #
  # This fixture file includes two fixtures. Each YAML fixture (ie. record) is given a name and
  # is followed by an indented list of key/value pairs in the "key: value" format. Records are
  # separated by a blank line for your viewing pleasure.
  #
  # Note that fixtures are unordered. If you want ordered fixtures, use the omap YAML type.
  # See http://yaml.org/type/omap.html
  # for the specification. You will need ordered fixtures when you have foreign key constraints
  # on keys in the same table. This is commonly needed for tree structures. Example:
  #
  #    --- !omap
  #    - parent:
  #        id:         1
  #        parent_id:  NULL
  #        title:      Parent
  #    - child:
  #        id:         2
  #        parent_id:  1
  #        title:      Child
  #
  # = Using Fixtures in Test Cases
  #
  # Since fixtures are a testing construct, we use them in our unit and functional tests. There
  # are two ways to use the fixtures, but first let's take a look at a sample unit test:
  #
  #   require 'test_helper'
  #
  #   class WebSiteTest < ActiveSupport::TestCase
  #     test "web_site_count" do
  #       assert_equal 2, WebSite.count
  #     end
  #   end
  #
  # By default, <tt>test_helper.rb</tt> will load all of your fixtures into your test database,
  # so this test will succeed.
  #
  # The testing environment will automatically load the all fixtures into the database before each
  # test. To ensure consistent data, the environment deletes the fixtures before running the load.
  #
  # In addition to being available in the database, the fixture's data may also be accessed by
  # using a special dynamic method, which has the same name as the model, and accepts the
  # name of the fixture to instantiate:
  #
  #   test "find" do
  #     assert_equal "Ruby on Rails", web_sites(:rubyonrails).name
  #   end
  #
  # Alternatively, you may enable auto-instantiation of the fixture data. For instance, take the
  # following tests:
  #
  #   test "find_alt_method_1" do
  #     assert_equal "Ruby on Rails", @web_sites['rubyonrails']['name']
  #   end
  #
  #   test "find_alt_method_2" do
  #     assert_equal "Ruby on Rails", @rubyonrails.news
  #   end
  #
  # In order to use these methods to access fixtured data within your testcases, you must specify one of the
  # following in your <tt>ActiveSupport::TestCase</tt>-derived class:
  #
  # - to fully enable instantiated fixtures (enable alternate methods #1 and #2 above)
  #     self.use_instantiated_fixtures = true
  #
  # - create only the hash for the fixtures, do not 'find' each instance (enable alternate method #1 only)
  #     self.use_instantiated_fixtures = :no_instances
  #
  # Using either of these alternate methods incurs a performance hit, as the fixtured data must be fully
  # traversed in the database to create the fixture hash and/or instance variables. This is expensive for
  # large sets of fixtured data.
  #
  # = Dynamic fixtures with ERB
  #
  # Some times you don't care about the content of the fixtures as much as you care about the volume.
  # In these cases, you can mix ERB in with your YAML fixtures to create a bunch of fixtures for load
  # testing, like:
  #
  #   <% 1.upto(1000) do |i| %>
  #   fix_<%= i %>:
  #     id: <%= i %>
  #     name: guy_<%= 1 %>
  #   <% end %>
  #
  # This will create 1000 very simple fixtures.
  #
  # Using ERB, you can also inject dynamic values into your fixtures with inserts like
  # <tt><%= Date.today.strftime("%Y-%m-%d") %></tt>.
  # This is however a feature to be used with some caution. The point of fixtures are that they're
  # stable units of predictable sample data. If you feel that you need to inject dynamic values, then
  # perhaps you should reexamine whether your application is properly testable. Hence, dynamic values
  # in fixtures are to be considered a code smell.
  #
  # = Transactional Fixtures
  #
  # Test cases can use begin+rollback to isolate their changes to the database instead of having to
  # delete+insert for every test case.
  #
  #   class FooTest < ActiveSupport::TestCase
  #     self.use_transactional_fixtures = true
  #
  #     test "godzilla" do
  #       assert !Foo.all.empty?
  #       Foo.destroy_all
  #       assert Foo.all.empty?
  #     end
  #
  #     test "godzilla aftermath" do
  #       assert !Foo.all.empty?
  #     end
  #   end
  #
  # If you preload your test database with all fixture data (probably in the rake task) and use
  # transactional fixtures, then you may omit all fixtures declarations in your test cases since
  # all the data's already there and every case rolls back its changes.
  #
  # In order to use instantiated fixtures with preloaded data, set +self.pre_loaded_fixtures+ to
  # true. This will provide access to fixture data for every table that has been loaded through
  # fixtures (depending on the value of +use_instantiated_fixtures+).
  #
  # When *not* to use transactional fixtures:
  #
  # 1. You're testing whether a transaction works correctly. Nested transactions don't commit until
  #    all parent transactions commit, particularly, the fixtures transaction which is begun in setup
  #    and rolled back in teardown. Thus, you won't be able to verify
  #    the results of your transaction until Active Record supports nested transactions or savepoints (in progress).
  # 2. Your database does not support transactions. Every Active Record database supports transactions except MySQL MyISAM.
  #    Use InnoDB, MaxDB, or NDB instead.
  #
  # = Advanced Fixtures
  #
  # Fixtures that don't specify an ID get some extra features:
  #
  # * Stable, autogenerated IDs
  # * Label references for associations (belongs_to, has_one, has_many)
  # * HABTM associations as inline lists
  # * Autofilled timestamp columns
  # * Fixture label interpolation
  # * Support for YAML defaults
  #
  # == Stable, Autogenerated IDs
  #
  # Here, have a monkey fixture:
  #
  #   george:
  #     id: 1
  #     name: George the Monkey
  #
  #   reginald:
  #     id: 2
  #     name: Reginald the Pirate
  #
  # Each of these fixtures has two unique identifiers: one for the database
  # and one for the humans. Why don't we generate the primary key instead?
  # Hashing each fixture's label yields a consistent ID:
  #
  #   george: # generated id: 503576764
  #     name: George the Monkey
  #
  #   reginald: # generated id: 324201669
  #     name: Reginald the Pirate
  #
  # Active Record looks at the fixture's model class, discovers the correct
  # primary key, and generates it right before inserting the fixture
  # into the database.
  #
  # The generated ID for a given label is constant, so we can discover
  # any fixture's ID without loading anything, as long as we know the label.
  #
  # == Label references for associations (belongs_to, has_one, has_many)
  #
  # Specifying foreign keys in fixtures can be very fragile, not to
  # mention difficult to read. Since Active Record can figure out the ID of
  # any fixture from its label, you can specify FK's by label instead of ID.
  #
  # === belongs_to
  #
  # Let's break out some more monkeys and pirates.
  #
  #   ### in pirates.yml
  #
  #   reginald:
  #     id: 1
  #     name: Reginald the Pirate
  #     monkey_id: 1
  #
  #   ### in monkeys.yml
  #
  #   george:
  #     id: 1
  #     name: George the Monkey
  #     pirate_id: 1
  #
  # Add a few more monkeys and pirates and break this into multiple files,
  # and it gets pretty hard to keep track of what's going on. Let's
  # use labels instead of IDs:
  #
  #   ### in pirates.yml
  #
  #   reginald:
  #     name: Reginald the Pirate
  #     monkey: george
  #
  #   ### in monkeys.yml
  #
  #   george:
  #     name: George the Monkey
  #     pirate: reginald
  #
  # Pow! All is made clear. Active Record reflects on the fixture's model class,
  # finds all the +belongs_to+ associations, and allows you to specify
  # a target *label* for the *association* (monkey: george) rather than
  # a target *id* for the *FK* (<tt>monkey_id: 1</tt>).
  #
  # ==== Polymorphic belongs_to
  #
  # Supporting polymorphic relationships is a little bit more complicated, since
  # Active Record needs to know what type your association is pointing at. Something
  # like this should look familiar:
  #
  #   ### in fruit.rb
  #
  #   belongs_to :eater, :polymorphic => true
  #
  #   ### in fruits.yml
  #
  #   apple:
  #     id: 1
  #     name: apple
  #     eater_id: 1
  #     eater_type: Monkey
  #
  # Can we do better? You bet!
  #
  #   apple:
  #     eater: george (Monkey)
  #
  # Just provide the polymorphic target type and Active Record will take care of the rest.
  #
  # === has_and_belongs_to_many
  #
  # Time to give our monkey some fruit.
  #
  #   ### in monkeys.yml
  #
  #   george:
  #     id: 1
  #     name: George the Monkey
  #
  #   ### in fruits.yml
  #
  #   apple:
  #     id: 1
  #     name: apple
  #
  #   orange:
  #     id: 2
  #     name: orange
  #
  #   grape:
  #     id: 3
  #     name: grape
  #
  #   ### in fruits_monkeys.yml
  #
  #   apple_george:
  #     fruit_id: 1
  #     monkey_id: 1
  #
  #   orange_george:
  #     fruit_id: 2
  #     monkey_id: 1
  #
  #   grape_george:
  #     fruit_id: 3
  #     monkey_id: 1
  #
  # Let's make the HABTM fixture go away.
  #
  #   ### in monkeys.yml
  #
  #   george:
  #     id: 1
  #     name: George the Monkey
  #     fruits: apple, orange, grape
  #
  #   ### in fruits.yml
  #
  #   apple:
  #     name: apple
  #
  #   orange:
  #     name: orange
  #
  #   grape:
  #     name: grape
  #
  # Zap! No more fruits_monkeys.yml file. We've specified the list of fruits
  # on George's fixture, but we could've just as easily specified a list
  # of monkeys on each fruit. As with +belongs_to+, Active Record reflects on
  # the fixture's model class and discovers the +has_and_belongs_to_many+
  # associations.
  #
  # == Autofilled Timestamp Columns
  #
  # If your table/model specifies any of Active Record's
  # standard timestamp columns (+created_at+, +created_on+, +updated_at+, +updated_on+),
  # they will automatically be set to <tt>Time.now</tt>.
  #
  # If you've set specific values, they'll be left alone.
  #
  # == Fixture label interpolation
  #
  # The label of the current fixture is always available as a column value:
  #
  #   geeksomnia:
  #     name: Geeksomnia's Account
  #     subdomain: $LABEL
  #
  # Also, sometimes (like when porting older join table fixtures) you'll need
  # to be able to get a hold of the identifier for a given label. ERB
  # to the rescue:
  #
  #   george_reginald:
  #     monkey_id: <%= ActiveRecord::Fixtures.identify(:reginald) %>
  #     pirate_id: <%= ActiveRecord::Fixtures.identify(:george) %>
  #
  # == Support for YAML defaults
  #
  # You probably already know how to use YAML to set and reuse defaults in
  # your <tt>database.yml</tt> file. You can use the same technique in your fixtures:
  #
  #   DEFAULTS: &DEFAULTS
  #     created_on: <%= 3.weeks.ago.to_s(:db) %>
  #
  #   first:
  #     name: Smurf
  #     *DEFAULTS
  #
  #   second:
  #     name: Fraggle
  #     *DEFAULTS
  #
  # Any fixture labeled "DEFAULTS" is safely ignored.
  class Fixtures
    MAX_ID = 2 ** 30 - 1

    @@all_cached_fixtures = Hash.new { |h,k| h[k] = {} }

    def self.find_table_name(table_name) # :nodoc:
      ActiveRecord::Base.pluralize_table_names ?
        table_name.to_s.singularize.camelize :
        table_name.to_s.camelize
    end

    def self.reset_cache
      @@all_cached_fixtures.clear
    end

    def self.cache_for_connection(connection)
      @@all_cached_fixtures[connection]
    end

    def self.fixture_is_cached?(connection, table_name)
      cache_for_connection(connection)[table_name]
    end

    def self.cached_fixtures(connection, keys_to_fetch = nil)
      if keys_to_fetch
        cache_for_connection(connection).values_at(*keys_to_fetch)
      else
        cache_for_connection(connection).values
      end
    end

    def self.cache_fixtures(connection, fixtures_map)
      cache_for_connection(connection).update(fixtures_map)
    end

    #--
    # TODO:NOTE: in the next version, the __with_new_arity suffix and
    #   the method with the old arity will be removed.
    #++
    def self.instantiate_fixtures__with_new_arity(object, fixture_set, load_instances = true) # :nodoc:
      if load_instances
        fixture_set.each do |fixture_name, fixture|
          begin
            object.instance_variable_set "@#{fixture_name}", fixture.find
          rescue FixtureClassNotFound
            nil
          end
        end
      end
    end

    # The use with parameters  <tt>(object, fixture_set_name, fixture_set, load_instances = true)</tt>  is deprecated,  +fixture_set_name+  parameter is not used.
    # Use as:
    #
    #   instantiate_fixtures(object, fixture_set, load_instances = true)
    def self.instantiate_fixtures(object, fixture_set, load_instances = true, rails_3_2_compatibility_argument = true)
      unless load_instances == true || load_instances == false
        ActiveSupport::Deprecation.warn(
          "ActiveRecord::Fixtures.instantiate_fixtures with parameters (object, fixture_set_name, fixture_set, load_instances = true) is deprecated and shall be removed from future releases.  Use it with parameters (object, fixture_set, load_instances = true) instead (skip fixture_set_name).",
          caller)
        fixture_set = load_instances
        load_instances = rails_3_2_compatibility_argument
      end
      instantiate_fixtures__with_new_arity(object, fixture_set, load_instances)
    end

    def self.instantiate_all_loaded_fixtures(object, load_instances = true)
      all_loaded_fixtures.each_value do |fixture_set|
        ActiveRecord::Fixtures.instantiate_fixtures(object, fixture_set, load_instances)
      end
    end

    cattr_accessor :all_loaded_fixtures
    self.all_loaded_fixtures = {}

    def self.create_fixtures(fixtures_directory, table_names, class_names = {})
      table_names = [table_names].flatten.map { |n| n.to_s }
      table_names.each { |n|
        class_names[n.tr('/', '_').to_sym] = n.classify if n.include?('/')
      }

      # FIXME: Apparently JK uses this.
      connection = block_given? ? yield : ActiveRecord::Base.connection

      files_to_read = table_names.reject { |table_name|
        fixture_is_cached?(connection, table_name)
      }

      unless files_to_read.empty?
        connection.disable_referential_integrity do
          fixtures_map = {}

          fixture_files = files_to_read.map do |path|
            table_name = path.tr '/', '_'

            fixtures_map[path] = ActiveRecord::Fixtures.new(
              connection,
              table_name,
              class_names[table_name.to_sym] || table_name.classify,
              ::File.join(fixtures_directory, path))
          end

          all_loaded_fixtures.update(fixtures_map)

          connection.transaction(:requires_new => true) do
            fixture_files.each do |ff|
              conn = ff.model_class.respond_to?(:connection) ? ff.model_class.connection : connection
              table_rows = ff.table_rows

              table_rows.keys.each do |table|
                conn.delete "DELETE FROM #{conn.quote_table_name(table)}", 'Fixture Delete'
              end

              table_rows.each do |table_name,rows|
                rows.each do |row|
                  conn.insert_fixture(row, table_name)
                end
              end
            end

            # Cap primary key sequences to max(pk).
            if connection.respond_to?(:reset_pk_sequence!)
              table_names.each do |table_name|
                connection.reset_pk_sequence!(table_name.tr('/', '_'))
              end
            end
          end

          cache_fixtures(connection, fixtures_map)
        end
      end
      cached_fixtures(connection, table_names)
    end

    # Returns a consistent, platform-independent identifier for +label+.
    # Identifiers are positive integers less than 2^32.
    def self.identify(label)
      Zlib.crc32(label.to_s) % MAX_ID
    end

    attr_reader :table_name, :name, :fixtures, :model_class

    def initialize(connection, table_name, class_name, fixture_path)
      @connection   = connection
      @table_name   = table_name
      @fixture_path = fixture_path
      @name         = table_name # preserve fixture base name
      @class_name   = class_name

      @fixtures     = ActiveSupport::OrderedHash.new
      @table_name   = "#{ActiveRecord::Base.table_name_prefix}#{@table_name}#{ActiveRecord::Base.table_name_suffix}"

      # Should be an AR::Base type class
      if class_name.is_a?(Class)
        @table_name   = class_name.table_name
        @connection   = class_name.connection
        @model_class  = class_name
      else
        @model_class  = class_name.constantize rescue nil
      end

      read_fixture_files
    end

    def [](x)
      fixtures[x]
    end

    def []=(k,v)
      fixtures[k] = v
    end

    def each(&block)
      fixtures.each(&block)
    end

    def size
      fixtures.size
    end

    # Return a hash of rows to be inserted. The key is the table, the value is
    # a list of rows to insert to that table.
    def table_rows
      now = ActiveRecord::Base.default_timezone == :utc ? Time.now.utc : Time.now
      now = now.to_s(:db)

      # allow a standard key to be used for doing defaults in YAML
      fixtures.delete('DEFAULTS')

      # track any join tables we need to insert later
      rows = Hash.new { |h,table| h[table] = [] }

      rows[table_name] = fixtures.map do |label, fixture|
        row = fixture.to_hash

        if model_class && model_class < ActiveRecord::Base
          # fill in timestamp columns if they aren't specified and the model is set to record_timestamps
          if model_class.record_timestamps
            timestamp_column_names.each do |name|
              row[name] = now unless row.key?(name)
            end
          end

          # interpolate the fixture label
          row.each do |key, value|
            row[key] = label if value.is_a?(String) && value == "$LABEL"
          end

          # generate a primary key if necessary
          if has_primary_key_column? && !row.include?(primary_key_name)
            row[primary_key_name] = ActiveRecord::Fixtures.identify(label)
          end

          # If STI is used, find the correct subclass for association reflection
          reflection_class =
            if row.include?(inheritance_column_name)
              row[inheritance_column_name].constantize rescue model_class
            else
              model_class
            end

          reflection_class.reflect_on_all_associations.each do |association|
            case association.macro
            when :belongs_to
              # Do not replace association name with association foreign key if they are named the same
              fk_name = (association.options[:foreign_key] || "#{association.name}_id").to_s

              if association.name.to_s != fk_name && value = row.delete(association.name.to_s)
                if association.options[:polymorphic] && value.sub!(/\s*\(([^\)]*)\)\s*$/, "")
                  # support polymorphic belongs_to as "label (Type)"
                  row[association.foreign_type] = $1
                end

                row[fk_name] = ActiveRecord::Fixtures.identify(value)
              end
            when :has_and_belongs_to_many
              if (targets = row.delete(association.name.to_s))
                targets = targets.is_a?(Array) ? targets : targets.split(/\s*,\s*/)
                table_name = association.options[:join_table]
                rows[table_name].concat targets.map { |target|
                  { association.foreign_key             => row[primary_key_name],
                    association.association_foreign_key => ActiveRecord::Fixtures.identify(target) }
                }
              end
            end
          end
        end

        row
      end
      rows
    end

    private
      def primary_key_name
        @primary_key_name ||= model_class && model_class.primary_key
      end

      def has_primary_key_column?
        @has_primary_key_column ||= primary_key_name &&
          model_class.columns.any? { |c| c.name == primary_key_name }
      end

      def timestamp_column_names
        @timestamp_column_names ||=
          %w(created_at created_on updated_at updated_on) & column_names
      end

      def inheritance_column_name
        @inheritance_column_name ||= model_class && model_class.inheritance_column
      end

      def column_names
        @column_names ||= @connection.columns(@table_name).collect { |c| c.name }
      end

      def read_fixture_files
        yaml_files = Dir["#{@fixture_path}/{**,*}/*.yml"].select { |f|
          ::File.file?(f)
        } + [yaml_file_path]

        yaml_files.each do |file|
          Fixtures::File.open(file) do |fh|
            fh.each do |name, row|
              fixtures[name] = ActiveRecord::Fixture.new(row, model_class)
            end
          end
        end
      end

      def yaml_file_path
        "#{@fixture_path}.yml"
      end

  end

  class Fixture #:nodoc:
    include Enumerable

    class FixtureError < StandardError #:nodoc:
    end

    class FormatError < FixtureError #:nodoc:
    end

    attr_reader :model_class, :fixture

    def initialize(fixture, model_class)
      @fixture     = fixture
      @model_class = model_class
    end

    def class_name
      model_class.name if model_class
    end

    def each
      fixture.each { |item| yield item }
    end

    def [](key)
      fixture[key]
    end

    alias :to_hash :fixture

    def find
      if model_class
        model_class.find(fixture[model_class.primary_key])
      else
        raise FixtureClassNotFound, "No class attached to find."
      end
    end
  end
end

module ActiveRecord
  module TestFixtures
    extend ActiveSupport::Concern

    included do
      setup :setup_fixtures
      teardown :teardown_fixtures

      class_attribute :fixture_path
      class_attribute :fixture_table_names
      class_attribute :fixture_class_names
      class_attribute :use_transactional_fixtures
      class_attribute :use_instantiated_fixtures   # true, false, or :no_instances
      class_attribute :pre_loaded_fixtures

      self.fixture_table_names = []
      self.use_transactional_fixtures = true
      self.use_instantiated_fixtures = false
      self.pre_loaded_fixtures = false

      self.fixture_class_names = Hash.new do |h, table_name|
        h[table_name] = ActiveRecord::Fixtures.find_table_name(table_name)
      end
    end

    module ClassMethods
      def set_fixture_class(class_names = {})
        self.fixture_class_names = self.fixture_class_names.merge(class_names)
      end

      def fixtures(*fixture_names)
        if fixture_names.first == :all
          fixture_names = Dir["#{fixture_path}/{**,*}/*.{yml}"]
          fixture_names.map! { |f| f[(fixture_path.size + 1)..-5] }
        else
          fixture_names = fixture_names.flatten.map { |n| n.to_s }
        end

        self.fixture_table_names |= fixture_names
        require_fixture_classes(fixture_names)
        setup_fixture_accessors(fixture_names)
      end

      def try_to_load_dependency(file_name)
        require_dependency file_name
      rescue LoadError => e
        # Let's hope the developer has included it himself

        # Let's warn in case this is a subdependency, otherwise
        # subdependency error messages are totally cryptic
        if ActiveRecord::Base.logger
          ActiveRecord::Base.logger.warn("Unable to load #{file_name}, underlying cause #{e.message} \n\n #{e.backtrace.join("\n")}")
        end
      end

      def require_fixture_classes(fixture_names = nil)
        (fixture_names || fixture_table_names).each do |fixture_name|
          file_name = fixture_name.to_s
          file_name = file_name.singularize if ActiveRecord::Base.pluralize_table_names
          try_to_load_dependency(file_name)
        end
      end

      def setup_fixture_accessors(fixture_names = nil)
        fixture_names = Array.wrap(fixture_names || fixture_table_names)
        methods = Module.new do
          fixture_names.each do |fixture_name|
            fixture_name = fixture_name.to_s.tr('./', '_')

            define_method(fixture_name) do |*fixtures|
              force_reload = fixtures.pop if fixtures.last == true || fixtures.last == :reload

              @fixture_cache[fixture_name] ||= {}

              instances = fixtures.map do |fixture|
                @fixture_cache[fixture_name].delete(fixture) if force_reload

                if @loaded_fixtures[fixture_name][fixture.to_s]
                  ActiveRecord::IdentityMap.without do
                    @fixture_cache[fixture_name][fixture] ||= @loaded_fixtures[fixture_name][fixture.to_s].find
                  end
                else
                  raise StandardError, "No fixture with name '#{fixture}' found for table '#{fixture_name}'"
                end
              end

              instances.size == 1 ? instances.first : instances
            end
            private fixture_name
          end
        end
        include methods
      end

      def uses_transaction(*methods)
        @uses_transaction = [] unless defined?(@uses_transaction)
        @uses_transaction.concat methods.map { |m| m.to_s }
      end

      def uses_transaction?(method)
        @uses_transaction = [] unless defined?(@uses_transaction)
        @uses_transaction.include?(method.to_s)
      end
    end

    def run_in_transaction?
      use_transactional_fixtures &&
        !self.class.uses_transaction?(method_name)
    end

    def setup_fixtures
      return unless !ActiveRecord::Base.configurations.blank?

      if pre_loaded_fixtures && !use_transactional_fixtures
        raise RuntimeError, 'pre_loaded_fixtures requires use_transactional_fixtures'
      end

      @fixture_cache = {}
      @fixture_connections = []
      @@already_loaded_fixtures ||= {}

      # Load fixtures once and begin transaction.
      if run_in_transaction?
        if @@already_loaded_fixtures[self.class]
          @loaded_fixtures = @@already_loaded_fixtures[self.class]
        else
          @loaded_fixtures = load_fixtures
          @@already_loaded_fixtures[self.class] = @loaded_fixtures
        end
        @fixture_connections = enlist_fixture_connections
        @fixture_connections.each do |connection|
          connection.increment_open_transactions
          connection.transaction_joinable = false
          connection.begin_db_transaction
        end
      # Load fixtures for every test.
      else
        ActiveRecord::Fixtures.reset_cache
        @@already_loaded_fixtures[self.class] = nil
        @loaded_fixtures = load_fixtures
      end

      # Instantiate fixtures for every test if requested.
      instantiate_fixtures if use_instantiated_fixtures
    end

    def teardown_fixtures
      return unless defined?(ActiveRecord) && !ActiveRecord::Base.configurations.blank?

      unless run_in_transaction?
        ActiveRecord::Fixtures.reset_cache
      end

      # Rollback changes if a transaction is active.
      if run_in_transaction?
        @fixture_connections.each do |connection|
          if connection.open_transactions != 0
            connection.rollback_db_transaction
            connection.decrement_open_transactions
          end
        end
        @fixture_connections.clear
      end
      ActiveRecord::Base.clear_active_connections!
    end

    def enlist_fixture_connections
      ActiveRecord::Base.connection_handler.connection_pools.values.map(&:connection)
    end

    private
      def load_fixtures
        fixtures = ActiveRecord::Fixtures.create_fixtures(fixture_path, fixture_table_names, fixture_class_names)
        Hash[fixtures.map { |f| [f.name, f] }]
      end

      # for pre_loaded_fixtures, only require the classes once. huge speed improvement
      @@required_fixture_classes = false

      def instantiate_fixtures
        if pre_loaded_fixtures
          raise RuntimeError, 'Load fixtures before instantiating them.' if ActiveRecord::Fixtures.all_loaded_fixtures.empty?
          unless @@required_fixture_classes
            self.class.require_fixture_classes ActiveRecord::Fixtures.all_loaded_fixtures.keys
            @@required_fixture_classes = true
          end
          ActiveRecord::Fixtures.instantiate_all_loaded_fixtures(self, load_instances?)
        else
          raise RuntimeError, 'Load fixtures before instantiating them.' if @loaded_fixtures.nil?
          @loaded_fixtures.each_value do |fixture_set|
            ActiveRecord::Fixtures.instantiate_fixtures(self, fixture_set, load_instances?)
          end
        end
      end

      def load_instances?
        use_instantiated_fixtures != :no_instances
      end
  end
end
