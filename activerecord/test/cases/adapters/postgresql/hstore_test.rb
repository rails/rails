# encoding: utf-8

require "cases/helper"
require 'active_record/base'
require 'active_record/connection_adapters/postgresql_adapter'

class PostgresqlHstoreTest < ActiveRecord::TestCase
  class Hstore < ActiveRecord::Base
    self.table_name = 'hstores'
  end

  def setup
    @connection = ActiveRecord::Base.connection

    unless @connection.supports_extensions?
      return skip "do not test on PG without hstore"
    end

    unless @connection.extension_enabled?('hstore')
      @connection.enable_extension 'hstore'
      @connection.commit_db_transaction
    end

    @connection.reconnect!

    @connection.transaction do
      @connection.create_table('hstores') do |t|
        t.hstore 'tags', :default => ''
        t.hstore 'payload', array: true
      end
    end
    @column = Hstore.columns.find { |c| c.name == 'tags' }
  end

  def teardown
    @connection.execute 'drop table if exists hstores'
  end

  def test_hstore_included_in_extensions
    assert @connection.respond_to?(:extensions), "connection should have a list of extensions"
    assert @connection.extensions.include?('hstore'), "extension list should include hstore"
  end

  def test_disable_enable_hstore
    assert @connection.extension_enabled?('hstore')
    @connection.disable_extension 'hstore'
    assert_not @connection.extension_enabled?('hstore')
    @connection.enable_extension 'hstore'
    assert @connection.extension_enabled?('hstore')
  ensure
    # Restore column(s) dropped by `drop extension hstore cascade;`
    load_schema
  end

  def test_column
    assert_equal :hstore, @column.type
  end

  def test_change_table_supports_hstore
    @connection.transaction do
      @connection.change_table('hstores') do |t|
        t.hstore 'users', default: ''
      end
      Hstore.reset_column_information
      column = Hstore.columns.find { |c| c.name == 'users' }
      assert_equal :hstore, column.type

      raise ActiveRecord::Rollback # reset the schema change
    end
  ensure
    Hstore.reset_column_information
  end

  def test_hstore_migration
    hstore_migration = Class.new(ActiveRecord::Migration) do
      def change
        change_table("hstores") do |t|
          t.hstore :keys
        end
      end
    end

    hstore_migration.new.suppress_messages do
      hstore_migration.migrate(:up)
      assert_includes @connection.columns(:hstores).map(&:name), "keys"
      hstore_migration.migrate(:down)
      assert_not_includes @connection.columns(:hstores).map(&:name), "keys"
    end
  end


  def test_type_cast_hstore
    assert @column

    data = "\"1\"=>\"2\""
    hash = @column.class.string_to_hstore data
    assert_equal({'1' => '2'}, hash)
    assert_equal({'1' => '2'}, @column.type_cast(data))

    assert_equal({}, @column.type_cast(""))
    assert_equal({'key'=>nil}, @column.type_cast('key => NULL'))
    assert_equal({'c'=>'}','"a"'=>'b "a b'}, @column.type_cast(%q(c=>"}", "\"a\""=>"b \"a b")))
  end

  def test_gen1
    assert_equal(%q(" "=>""), @column.class.hstore_to_string({' '=>''}))
  end

  def test_gen2
    assert_equal(%q(","=>""), @column.class.hstore_to_string({','=>''}))
  end

  def test_gen3
    assert_equal(%q("="=>""), @column.class.hstore_to_string({'='=>''}))
  end

  def test_gen4
    assert_equal(%q(">"=>""), @column.class.hstore_to_string({'>'=>''}))
  end

  def test_parse1
    assert_equal({'a'=>nil,'b'=>nil,'c'=>'NuLl','null'=>'c'}, @column.type_cast('a=>null,b=>NuLl,c=>"NuLl",null=>c'))
  end

  def test_parse2
    assert_equal({" " => " "},  @column.type_cast("\\ =>\\ "))
  end

  def test_parse3
    assert_equal({"=" => ">"},  @column.type_cast("==>>"))
  end

  def test_parse4
    assert_equal({"=a"=>"q=w"},   @column.type_cast('\=a=>q=w'))
  end

  def test_parse5
    assert_equal({"=a"=>"q=w"},   @column.type_cast('"=a"=>q\=w'))
  end

  def test_parse6
    assert_equal({"\"a"=>"q>w"},  @column.type_cast('"\"a"=>q>w'))
  end

  def test_parse7
    assert_equal({"\"a"=>"q\"w"}, @column.type_cast('\"a=>q"w'))
  end

  def test_rewrite
    @connection.execute "insert into hstores (tags) VALUES ('1=>2')"
    x = Hstore.first
    x.tags = { '"a\'' => 'b' }
    assert x.save!
  end

  def test_select
    @connection.execute "insert into hstores (tags) VALUES ('1=>2')"
    x = Hstore.first
    assert_equal({'1' => '2'}, x.tags)
  end

  def test_array_cycle
    assert_array_cycle([{"AA" => "BB", "CC" => "DD"}, {"AA" => nil}])
  end

  def test_array_strings_with_quotes
    assert_array_cycle([{'this has' => 'some "s that need to be escaped"'}])
  end

  def test_array_strings_with_commas
    assert_array_cycle([{'this,has' => 'many,values'}])
  end

  def test_array_strings_with_array_delimiters
    assert_array_cycle(['{' => '}'])
  end

  def test_array_strings_with_null_strings
    assert_array_cycle([{'NULL' => 'NULL'}])
  end

  def test_contains_nils
    assert_array_cycle([{'NULL' => nil}])
  end

  def test_select_multikey
    @connection.execute "insert into hstores (tags) VALUES ('1=>2,2=>3')"
    x = Hstore.first
    assert_equal({'1' => '2', '2' => '3'}, x.tags)
  end

  def test_create
    assert_cycle('a' => 'b', '1' => '2')
  end

  def test_nil
    assert_cycle('a' => nil)
  end

  def test_quotes
    assert_cycle('a' => 'b"ar', '1"foo' => '2')
  end

  def test_whitespace
    assert_cycle('a b' => 'b ar', '1"foo' => '2')
  end

  def test_backslash
    assert_cycle('a\\b' => 'b\\ar', '1"foo' => '2')
  end

  def test_comma
    assert_cycle('a, b' => 'bar', '1"foo' => '2')
  end

  def test_arrow
    assert_cycle('a=>b' => 'bar', '1"foo' => '2')
  end

  def test_quoting_special_characters
    assert_cycle('ca' => 'cà', 'ac' => 'àc')
  end

  def test_multiline
    assert_cycle("a\nb" => "c\nd")
  end

  def test_update_all
    hstore = Hstore.create! tags: { "one" => "two" }

    Hstore.update_all tags: { "three" => "four" }
    assert_equal({ "three" => "four" }, hstore.reload.tags)

    Hstore.update_all tags: { }
    assert_equal({ }, hstore.reload.tags)
  end

  private

    def assert_array_cycle(array)
      # test creation
      x = Hstore.create!(payload: array)
      x.reload
      assert_equal(array, x.payload)

      # test updating
      x = Hstore.create!(payload: [])
      x.payload = array
      x.save!
      x.reload
      assert_equal(array, x.payload)
    end

    def assert_cycle(hash)
      # test creation
      x = Hstore.create!(:tags => hash)
      x.reload
      assert_equal(hash, x.tags)

      # test updating
      x = Hstore.create!(:tags => {})
      x.tags = hash
      x.save!
      x.reload
      assert_equal(hash, x.tags)
    end
end
