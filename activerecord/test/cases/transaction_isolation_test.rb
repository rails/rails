require 'cases/helper'

class TransactionIsolationUnsupportedTest < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  class Tag < ActiveRecord::Base
  end

  setup do
    if ActiveRecord::Base.connection.supports_transaction_isolation?
      skip "database supports transaction isolation; test is irrelevant"
    end
  end

  test "setting the isolation level raises an error" do
    assert_raises(ActiveRecord::TransactionIsolationError) do
      Tag.transaction(isolation: :serializable) { }
    end
  end
end

class TransactionIsolationTest < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  class Tag < ActiveRecord::Base
    self.table_name = 'tags'
  end

  class Tag2 < ActiveRecord::Base
    self.table_name = 'tags'
  end

  setup do
    unless ActiveRecord::Base.connection.supports_transaction_isolation?
      skip "database does not support setting transaction isolation"
    end

    Tag.establish_connection 'arunit'
    Tag2.establish_connection 'arunit'
    Tag.destroy_all
  end

  # It is impossible to properly test read uncommitted. The SQL standard only
  # specifies what must not happen at a certain level, not what must happen. At
  # the read uncommitted level, there is nothing that must not happen.
  test "read uncommitted" do
    unless ActiveRecord::Base.connection.transaction_isolation_levels.include?(:read_uncommitted)
      skip "database does not support read uncommitted isolation level"
    end
    Tag.transaction(isolation: :read_uncommitted) do
      assert_equal 0, Tag.count
      Tag2.create
      assert_equal 1, Tag.count
    end
  end

  # We are testing that a dirty read does not happen
  test "read committed" do
    Tag.transaction(isolation: :read_committed) do
      assert_equal 0, Tag.count

      Tag2.transaction do
        Tag2.create
        assert_equal 0, Tag.count
      end
    end

    assert_equal 1, Tag.count
  end

  # We are testing that a nonrepeatable read does not happen
  test "repeatable read" do
    unless ActiveRecord::Base.connection.transaction_isolation_levels.include?(:repeatable_read)
      skip "database does not support repeatable read isolation level"
    end
    tag = Tag.create(name: 'jon')

    Tag.transaction(isolation: :repeatable_read) do
      tag.reload
      Tag2.find(tag.id).update_attributes(name: 'emily')

      tag.reload
      assert_equal 'jon', tag.name
    end

    tag.reload
    assert_equal 'emily', tag.name
  end

  # We are only testing that there are no errors because it's too hard to
  # test serializable. Databases behave differently to enforce the serializability
  # constraint.
  test "serializable" do
    Tag.transaction(isolation: :serializable) do
      Tag.create
    end
  end

  test "setting isolation when joining a transaction raises an error" do
    Tag.transaction do
      assert_raises(ActiveRecord::TransactionIsolationError) do
        Tag.transaction(isolation: :serializable) { }
      end
    end
  end

  test "setting isolation when starting a nested transaction raises error" do
    Tag.transaction do
      assert_raises(ActiveRecord::TransactionIsolationError) do
        Tag.transaction(requires_new: true, isolation: :serializable) { }
      end
    end
  end
end
