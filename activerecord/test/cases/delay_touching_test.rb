require 'cases/helper'
require 'models/owner'
require 'models/pet'

class DelayTouchingTest < ActiveRecord::TestCase
  fixtures :owners, :pets

  setup do
    Owner.reset_touch_callbacks
  end

  test "touch returns true when not in a delay_touching block" do
    assert_equal true, owner.touch
  end

  test "touch returns true in a delay_touching block" do
    ActiveRecord::Base.transaction do
      assert_equal true, owner.touch
    end
  end

  test "delay_touching consolidates touches on a single record when inside a transaction" do
    expect_updates [{ "owners" => { ids: owner } }] do
      ActiveRecord::Base.transaction do
        owner.touch
        owner.touch
      end
    end
  end

  test "delay_touching calls the after_touch callback just once, after the record has been written" do
    ActiveRecord::Base.transaction do
      owner.stubs(:after_touch_callback).never
      owner.touch
      owner.touch
      owner.stubs(:after_touch_callback).once
    end
  end

  test "delay_touching sets updated_at on the in-memory instance when it eventually touches the record" do
    original_time = new_time = nil

    Time.stubs(:now).returns(Time.new(2014, 7, 4, 12, 0, 0))
    original_time = Time.current
    owner.touch

    Time.stubs(:now).returns(Time.new(2014, 7, 10, 12, 0, 0))
    new_time = Time.current
    ActiveRecord::Base.transaction do
      owner.touch
      assert_equal original_time, owner.updated_at
      assert_not owner.changed?
    end

    assert_equal new_time, owner.updated_at
    assert_not owner.changed?
  end

  test "delay_touching does not mark the instance as changed when touch is called" do
    ActiveRecord::Base.transaction do
      owner.touch
      assert_not owner.changed?
    end
  end

  test "delay_touching consolidates touches for all instances in a single table" do
    expect_updates [{ "pets" => { ids: [pet1, pet2] } }, "owners" => { ids: owner }] do
      ActiveRecord::Base.transaction do
        pet1.touch
        pet2.touch
      end
    end
  end

  test "does nothing if no_touching is on" do
    owner.stubs(:after_touch_callback).never
    expect_updates [] do
      ActiveRecord::Base.no_touching do
        ActiveRecord::Base.transaction do
          owner.touch
        end
      end
    end
  end

  test "delay_touching only applies touches for which no_touching is off" do
    owner.stubs(:after_touch_callback).never
    pet1.stubs(:after_touch_callback).once
    expect_updates ["pets" => { ids: pet1 }] do
      Owner.no_touching do
        ActiveRecord::Base.transaction do
          owner.touch
          pet1.touch
        end
      end
    end
  end

  test "delay_touching does not apply nested touches if no_touching was turned on inside delay_touching" do
    owner.stubs(:after_touch_callback).once
    pet1.stubs(:after_touch_callback).never
    expect_updates ["owners" => { ids: owner }] do
      ActiveRecord::Base.transaction do
        owner.touch
        ActiveRecord::Base.no_touching do
          pet1.touch
        end
      end
    end
  end

  test "delay_touching can update nonstandard columns" do
    expect_updates ["owners" => { ids: owner, columns: ["updated_at", "happy_at"] }] do
      ActiveRecord::Base.transaction do
        owner.touch :happy_at
      end
    end
  end

  test "delay_touching splits up nonstandard column touches and standard column touches" do
    expect_updates [{ "pets" => { ids: pet1, columns: ["updated_at", "neutered_at"] } },
                    { "pets" => { ids: pet2, columns: ["updated_at"] } },
                    { "owners" => { ids: owner } }] do

      ActiveRecord::Base.transaction do
        pet1.touch :neutered_at
        pet2.touch
      end
    end
  end

  test "delay_touching can update multiple nonstandard columns of a single record in different calls to touch" do
    expect_updates [{ "owners" => { ids: owner, columns: ["updated_at", "happy_at"] } },
                    { "owners" => { ids: owner, columns: ["updated_at", "sad_at"] } }] do

      ActiveRecord::Base.transaction do
        owner.touch :happy_at
        owner.touch :sad_at
      end
    end
  end

  test "delay_touching can update multiple nonstandard columns of a single record in a single call to touch" do
    expect_updates [{ "owners" => { ids: owner, columns: [ "updated_at", "happy_at", "sad_at"] } }] do

      ActiveRecord::Base.transaction do
        owner.touch :happy_at, :sad_at
      end
    end
  end

  test "delay_touching consolidates touch: true touches" do
    expect_updates [{ "pets" => { ids: [pet1, pet2] } }, { "owners" => { ids: owner } }] do
      ActiveRecord::Base.transaction do
        pet1.touch
        pet2.touch
      end
    end
  end

  test "delay_touching does not touch the owning record via touch: true if it was already touched explicitly" do
    pet1.stubs(:after_touch_callback).once
    pet2.stubs(:after_touch_callback).once

    expect_updates [{ "pets" => { ids: [pet1, pet2] } }, { "owners" => { ids: owner } }] do
      ActiveRecord::Base.transaction do
        owner.touch
        pet1.touch
        pet2.touch
      end
    end

    assert_equal 1, Owner.after_touch_callbacks
  end

  test "delay_touching does not consolidate touches when outside a transaction" do
    expect_updates [{ "owners" => { ids: owner } },
                    { "owners" => { ids: owner } }] do
      owner.touch
      owner.touch
    end
  end

  test "nested transactions get consolidated into a single set of touches" do
    pet1.stubs(:after_touch_callback).once
    pet2.stubs(:after_touch_callback).once

    expect_updates [{ "pets" => { ids: [pet1, pet2] } }, { "owners" => { ids: owner } }] do
      ActiveRecord::Base.transaction do
        pet1.touch
        ActiveRecord::Base.transaction do
          pet2.touch
        end
      end
    end

    assert_equal 1, Owner.after_touch_callbacks
  end

  test "rolling back from a nested transaction without :requires_new touches the records in the inner transaction" do
    expect_updates [{ "pets" => { ids: [pet1, pet2] } }, { "owners" => { ids: owner } }] do
      ActiveRecord::Base.transaction do
        pet1.touch
        ActiveRecord::Base.transaction do
          pet2.touch
          raise ActiveRecord::Rollback
        end
      end
    end
  end

  test "rolling back from a nested transaction with :requires_new does not touch the records in the inner transaction" do
    expect_updates [{ "pets" => { ids: pet1 } }, { "owners" => { ids: owner } }] do
      ActiveRecord::Base.transaction do
        pet1.touch
        ActiveRecord::Base.transaction(requires_new: true) do
          pet2.touch
          raise ActiveRecord::Rollback
        end
      end
    end
  end

  test "touching a record in an outer and inner new transaction, then rolling back the inner one, still touches the record" do
    expect_updates [{ "pets" => { ids: pet1 } }, { "owners" => { ids: owner } }] do
      ActiveRecord::Base.transaction do
        pet1.touch
        ActiveRecord::Base.transaction(requires_new: true) do
          pet1.touch
          raise ActiveRecord::Rollback
        end
      end
    end
  end

  test "rolling back from an outer transaction does not touch any records" do
    expect_updates [] do
      ActiveRecord::Base.transaction do
        pet1.touch
        ActiveRecord::Base.transaction do
          pet2.touch :neutered_at
        end
        raise ActiveRecord::Rollback
      end
    end
  end

  test "delay_touching consolidates touch: :column_name touches" do
    pet_klass = Class.new(ActiveRecord::Base) do
      def self.name; 'Pet'; end
      belongs_to :owner, :touch => :happy_at
      after_touch :after_touch_callback
      def after_touch_callback; end
    end

    pet = pet_klass.first
    owner = pet.owner

    owner.stubs(:after_touch_callback).once
    pet.stubs(:after_touch_callback).once
    expect_updates [{ "owners" => { ids: owner, columns: ["updated_at", "happy_at"] } }, { "pets" => { ids: pet } }] do
      ActiveRecord::Base.transaction do
        pet.touch
        pet.touch
      end
    end
  end

  test "delay_touching keeps iterating as long as after_touch keeps causing more records to be touched" do
    pet_klass = Class.new(ActiveRecord::Base) do
      def self.name; 'Pet'; end
      belongs_to :owner

      # Touch the owner in after_touch instead of using touch: true
      after_touch :touch_owner
      def touch_owner; owner.touch; end
    end

    pet = pet_klass.first
    owner = pet.owner

    expect_updates [{ "owners" => { ids: owner } }, { "pets" => { ids: pet } }] do
      ActiveRecord::Base.transaction do
        pet.touch
      end
    end
  end

  private

  def owner
    @owner ||= owners(:blackbeard)
  end

  def pet1
    @pet1 ||= owner.pets.first
  end

  def pet2
    @pet2 ||= owner.pets.last
  end

  def expect_updates(tables_ids_and_columns)
    capture_sql { yield }
    expected_sql = expected_sql_for(tables_ids_and_columns)
    ActiveRecord::SQLCounter.log.each do |stmt|
      if stmt =~ /UPDATE /i
        index = expected_sql.index { |expected_stmt| stmt =~ expected_stmt }
        assert index, "An unexpected touch occurred: #{stmt}"
        expected_sql.delete_at(index)
      end
    end
    assert_empty expected_sql, "Some of the expected updates were not executed"
  end

  # Creates an array of regular expressions to match the SQL statements that we expect
  # to execute.
  #
  # Each element in the tables_ids_and_columns array is in this form:
  #
  #   { "table_name" => { ids: id_or_array_of_ids, columns: column_name_or_array } }
  #
  # 'columns' is optional. If it's missing it is assumed that "updated_at" is the only
  # column that gets touched.
  def expected_sql_for(tables_ids_and_columns)
    tables_ids_and_columns.map do |entry|
      entry.map do |table, options|
        ids = Array.wrap(options[:ids])
        columns = Array.wrap(options[:columns]).presence || ["updated_at"]
        columns = columns.sort
        Regexp.new(touch_sql(table, columns, ids))
      end
    end.flatten
  end

  # in:  array of records or record ids
  # out: "( = 1|= \?|= \$1)" or " IN (1, 2)"
  #
  # In some cases, such as SQLite3 when outside a transaction, the logged SQL uses ? instead of record ids.
  def ids_sql(ids)
    ids = ids.map { |id| id.class.respond_to?(:primary_key) ? id.send(id.class.primary_key) : id }
    ids.length > 1 ? %{ IN \\(#{ids.sort.join(", ")}\\)} : %{( = #{ids.first}|= \\?|= \\$1)}
  end

  def touch_sql(table, columns, ids)
    case ENV['ARCONN']
    when "mysql", "mysql2"
      %{UPDATE `#{table}` SET #{columns.map { |column| %{`#{table}`.`#{column}` =.+} }.join(", ") } .+#{ids_sql(ids)}\\Z}
    when "sqlite3", "postgresql"
      %{UPDATE "#{table}" SET #{columns.map { |column| %{"#{column}" =.+} }.join(", ") } .+#{ids_sql(ids)}\\Z}
    else raise "Unexpected database: #{ENV['ARCONN']}"
    end
  end
end

