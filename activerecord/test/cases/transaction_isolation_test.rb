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

  # We are testing that a non-serializable sequence of statements will raise
  # an error.
  test "serializable" do
    if Tag2.connection.adapter_name =~ /mysql/i
      # Unfortunately it cannot be set to 0
      Tag2.connection.execute "SET innodb_lock_wait_timeout = 1"
    end

    assert_raises ActiveRecord::StatementInvalid do
      Tag.transaction(isolation: :serializable) do
        Tag.create

        Tag2.transaction(isolation: :serializable) do
          Tag2.create
          Tag2.count
        end

        Tag.count
      end
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
