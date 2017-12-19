# frozen_string_literal: true

require "cases/helper"

class ReservedWordTest < ActiveRecord::TestCase
  self.use_instantiated_fixtures = true
  self.use_transactional_tests = false

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
    @connection.create_table :select, force: true
    @connection.create_table :distinct, force: true
    @connection.create_table :distinct_select, id: false, force: true do |t|
      t.belongs_to :distinct
      t.belongs_to :select
    end
    @connection.create_table :group, force: true do |t|
      t.string :order
      t.belongs_to :select
    end
    @connection.create_table :values, primary_key: :as, force: true do |t|
      t.belongs_to :group
    end
  end

  def teardown
    @connection.drop_table :select, if_exists: true
    @connection.drop_table :distinct, if_exists: true
    @connection.drop_table :distinct_select, if_exists: true
    @connection.drop_table :group, if_exists: true
    @connection.drop_table :values, if_exists: true
    @connection.drop_table :order, if_exists: true
  end

  def test_create_tables
    assert_not @connection.table_exists?(:order)

    @connection.create_table :order do |t|
      t.string :group
    end

    assert @connection.table_exists?(:order)
  end

  def test_rename_tables
    assert_nothing_raised { @connection.rename_table(:group, :order) }
  end

  def test_change_columns
    assert_nothing_raised { @connection.change_column_default(:group, :order, "whatever") }
    assert_nothing_raised { @connection.change_column("group", "order", :text, default: nil) }
    assert_nothing_raised { @connection.rename_column(:group, :order, :values) }
  end

  def test_introspect
    assert_equal ["id", "order", "select_id"], @connection.columns(:group).map(&:name).sort
    assert_equal ["index_group_on_select_id"], @connection.indexes(:group).map(&:name).sort
  end

  def test_activerecord_model
    x = Group.new
    x.order = "x"
    x.save!
    x.order = "y"
    x.save!
    assert_equal x, Group.find_by_order("y")
    assert_equal x, Group.find(x.id)
  end

  def test_delete_all_with_subselect
    create_test_fixtures :values
    assert_equal 1, Values.order(:as).limit(1).offset(1).delete_all
    assert_raise(ActiveRecord::RecordNotFound) { Values.find(2) }
    assert Values.find(1)
  end

  def test_has_one_associations
    create_test_fixtures :group, :values
    v = Group.find(1).values
    assert_equal 2, v.id
  end

  def test_belongs_to_associations
    create_test_fixtures :select, :group
    gs = Select.find(2).groups
    assert_equal 2, gs.length
    assert_equal [2, 3], gs.collect(&:id).sort
  end

  def test_has_and_belongs_to_many
    create_test_fixtures :select, :distinct, :distinct_select
    s = Distinct.find(1).selects
    assert_equal 2, s.length
    assert_equal [1, 2], s.collect(&:id).sort
  end

  def test_activerecord_introspection
    assert Group.table_exists?
    assert_equal ["id", "order", "select_id"], Group.columns.map(&:name).sort
  end

  def test_calculations_work_with_reserved_words
    create_test_fixtures :group
    assert_equal 3, Group.count
  end

  def test_associations_work_with_reserved_words
    create_test_fixtures :select, :group
    selects = Select.all.merge!(includes: [:groups]).to_a
    assert_no_queries do
      selects.each { |select| select.groups }
    end
  end

  private
    # custom fixture loader, uses FixtureSet#create_fixtures and appends base_path to the current file's path
    def create_test_fixtures(*fixture_names)
      ActiveRecord::FixtureSet.create_fixtures(FIXTURES_ROOT + "/reserved_words", fixture_names)
    end
end
