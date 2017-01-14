require "cases/helper"

# a suite of tests to ensure the ConnectionAdapters#MysqlAdapter can handle tables with
# reserved word names (ie: group, order, values, etc...)
class Mysql2ReservedWordTest < ActiveRecord::Mysql2TestCase
  class Group < ActiveRecord::Base
    Group.table_name = "group"
    belongs_to :select
    has_one :values
  end

  class Select < ActiveRecord::Base
    Select.table_name = "select"
    has_many :groups
  end

  class Values < ActiveRecord::Base
    Values.table_name = "values"
  end

  class Distinct < ActiveRecord::Base
    Distinct.table_name = "distinct"
    has_and_belongs_to_many :selects
    has_many :values, through: :groups
  end

  def setup
    @connection = ActiveRecord::Base.connection

    # we call execute directly here (and do similar below) because ActiveRecord::Base#create_table()
    # will fail with these table names if these test cases fail

    create_tables_directly "group" => "id int auto_increment primary key, `order` varchar(255), select_id int",
      "select" => "id int auto_increment primary key",
      "values" => "id int auto_increment primary key, group_id int",
      "distinct" => "id int auto_increment primary key",
      "distinct_select" => "distinct_id int, select_id int"
  end

  teardown do
    drop_tables_directly ["group", "select", "values", "distinct", "distinct_select", "order"]
  end

  # create tables with reserved-word names and columns
  def test_create_tables
    assert_nothing_raised {
      @connection.create_table :order do |t|
        t.column :group, :string
      end
    }
  end

  # rename tables with reserved-word names
  def test_rename_tables
    assert_nothing_raised { @connection.rename_table(:group, :order) }
  end

  # alter column with a reserved-word name in a table with a reserved-word name
  def test_change_columns
    assert_nothing_raised { @connection.change_column_default(:group, :order, "whatever") }
    #the quoting here will reveal any double quoting issues in change_column's interaction with the column method in the adapter
    assert_nothing_raised { @connection.change_column("group", "order", :Int, default: 0) }
    assert_nothing_raised { @connection.rename_column(:group, :order, :values) }
  end

  # introspect table with reserved word name
  def test_introspect
    assert_nothing_raised { @connection.columns(:group) }
    assert_nothing_raised { @connection.indexes(:group) }
  end

  #fixtures
  self.use_instantiated_fixtures = true
  self.use_transactional_tests = false

  #activerecord model class with reserved-word table name
  def test_activerecord_model
    create_test_fixtures :select, :distinct, :group, :values, :distinct_select
    x = nil
    assert_nothing_raised { x = Group.new }
    x.order = "x"
    assert_nothing_raised { x.save }
    x.order = "y"
    assert_nothing_raised { x.save }
    assert_nothing_raised { Group.find_by_order("y") }
    assert_nothing_raised { Group.find(1) }
  end

  # has_one association with reserved-word table name
  def test_has_one_associations
    create_test_fixtures :select, :distinct, :group, :values, :distinct_select
    v = nil
    assert_nothing_raised { v = Group.find(1).values }
    assert_equal 2, v.id
  end

  # belongs_to association with reserved-word table name
  def test_belongs_to_associations
    create_test_fixtures :select, :distinct, :group, :values, :distinct_select
    gs = nil
    assert_nothing_raised { gs = Select.find(2).groups }
    assert_equal gs.length, 2
    assert(gs.collect(&:id).sort == [2, 3])
  end

  # has_and_belongs_to_many with reserved-word table name
  def test_has_and_belongs_to_many
    create_test_fixtures :select, :distinct, :group, :values, :distinct_select
    s = nil
    assert_nothing_raised { s = Distinct.find(1).selects }
    assert_equal s.length, 2
    assert(s.collect(&:id).sort == [1, 2])
  end

  # activerecord model introspection with reserved-word table and column names
  def test_activerecord_introspection
    assert_nothing_raised { Group.table_exists? }
    assert_nothing_raised { Group.columns }
  end

  # Calculations
  def test_calculations_work_with_reserved_words
    assert_nothing_raised { Group.count }
  end

  def test_associations_work_with_reserved_words
    assert_nothing_raised { Select.all.merge!(includes: [:groups]).to_a }
  end

  #the following functions were added to DRY test cases

  private
    # custom fixture loader, uses FixtureSet#create_fixtures and appends base_path to the current file's path
    def create_test_fixtures(*fixture_names)
      ActiveRecord::FixtureSet.create_fixtures(FIXTURES_ROOT + "/reserved_words", fixture_names)
    end

    # custom drop table, uses execute on connection to drop a table if it exists. note: escapes table_name
    def drop_tables_directly(table_names, connection = @connection)
      table_names.each do |name|
        connection.drop_table name, if_exists: true
      end
    end

    # custom create table, uses execute on connection to create a table, note: escapes table_name, does NOT escape columns
    def create_tables_directly(tables, connection = @connection)
      tables.each do |table_name, column_properties|
        connection.execute("CREATE TABLE `#{table_name}` ( #{column_properties} )")
      end
    end
end
