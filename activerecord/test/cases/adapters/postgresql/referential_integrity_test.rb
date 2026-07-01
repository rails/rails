# frozen_string_literal: true

require "cases/helper"
require "support/connection_helper"

class PostgreSQLReferentialIntegrityTest < ActiveRecord::PostgreSQLTestCase
  include ConnectionHelper

  IS_REFERENTIAL_INTEGRITY_SQL = lambda do |sql|
    sql.match(/DISABLE TRIGGER ALL/) || sql.match(/ENABLE TRIGGER ALL/)
  end

  module MissingSuperuserPrivileges
    def execute(sql, name = nil)
      if IS_REFERENTIAL_INTEGRITY_SQL.call(sql)
        super "BROKEN;" rescue nil # put transaction in broken state
        raise ActiveRecord::StatementInvalid, "PG::InsufficientPrivilege"
      else
        super
      end
    end
  end

  module ProgrammerMistake
    def execute(sql, name = nil)
      if IS_REFERENTIAL_INTEGRITY_SQL.call(sql)
        raise ArgumentError, "something is not right."
      else
        super
      end
    end
  end

  def setup
    @connection = ActiveRecord::Base.lease_connection
    if @connection.supports_enforced_foreign_keys?
      @connection.create_table :ri_test_parents, force: true
      @connection.create_table :ri_test_children, force: true do |t|
        t.bigint :parent_id, null: false
      end
    end
  end

  def teardown
    @connection.drop_table :ri_test_children, if_exists: true
    @connection.drop_table :ri_test_parents, if_exists: true
    @connection.drop_table :ri_pp_children_0, if_exists: true
    @connection.drop_table :ri_pp_children, if_exists: true
    @connection.drop_table :ri_pp_parents_0, if_exists: true
    @connection.drop_table :ri_pp_parents, if_exists: true
    reset_pool
    if ActiveRecord::Base.lease_connection.is_a?(MissingSuperuserPrivileges)
      raise "MissingSuperuserPrivileges patch was not removed"
    end
  end

  def test_should_reraise_invalid_foreign_key_exception_and_show_warning
    skip if @connection.supports_enforced_foreign_keys?
    @connection.extend MissingSuperuserPrivileges

    warning = capture(:stderr) do
      e = assert_raises(ActiveRecord::InvalidForeignKey) do
        @connection.disable_referential_integrity do
          raise ActiveRecord::InvalidForeignKey, "Should be re-raised"
        end
      end
      assert_equal "Should be re-raised", e.message
    end
    assert_match (/WARNING: Rails was not able to disable referential integrity/), warning
    assert_match (/cause: PG::InsufficientPrivilege/), warning
  end

  def test_does_not_print_warning_if_no_invalid_foreign_key_exception_was_raised
    skip if @connection.supports_enforced_foreign_keys?
    @connection.extend MissingSuperuserPrivileges

    warning = capture(:stderr) do
      e = assert_raises(ActiveRecord::StatementInvalid) do
        @connection.disable_referential_integrity do
          raise ActiveRecord::StatementInvalid, "Should be re-raised"
        end
      end
      assert_equal "Should be re-raised", e.message
    end
    assert_predicate warning, :blank?, "expected no warnings but got:\n#{warning}"
  end

  def test_does_not_break_transactions
    if @connection.supports_enforced_foreign_keys?
      @connection.add_foreign_key :ri_test_children, :ri_test_parents, column: :parent_id, name: :ri_test_fk
    else
      @connection.extend MissingSuperuserPrivileges
    end

    @connection.transaction do
      @connection.disable_referential_integrity do
        assert_transaction_is_not_broken
      end
      assert_transaction_is_not_broken
    end
  end

  def test_does_not_break_nested_transactions
    if @connection.supports_enforced_foreign_keys?
      @connection.add_foreign_key :ri_test_children, :ri_test_parents, column: :parent_id, name: :ri_test_fk
    else
      @connection.extend MissingSuperuserPrivileges
    end

    @connection.transaction do
      @connection.transaction(requires_new: true) do
        @connection.disable_referential_integrity do
          assert_transaction_is_not_broken
        end
      end
      assert_transaction_is_not_broken
    end
  end

  def test_only_catch_active_record_errors_others_bubble_up
    skip if @connection.supports_enforced_foreign_keys?
    @connection.extend ProgrammerMistake

    assert_raises ArgumentError do
      @connection.disable_referential_integrity { }
    end
  end

  def test_disable_referential_integrity_with_partitioned_to_partitioned_fk
    skip unless @connection.supports_enforced_foreign_keys?

    @connection.create_table :ri_pp_parents, force: true,
      options: "PARTITION BY RANGE (id)"
    @connection.execute "CREATE TABLE ri_pp_parents_0 PARTITION OF ri_pp_parents FOR VALUES FROM (0) TO (1000)"

    @connection.create_table :ri_pp_children, force: true,
      options: "PARTITION BY RANGE (id)" do |t|
      t.bigint :parent_id, null: false
    end
    @connection.execute "CREATE TABLE ri_pp_children_0 PARTITION OF ri_pp_children FOR VALUES FROM (0) TO (1000)"

    @connection.add_foreign_key :ri_pp_children, :ri_pp_parents,
      column: :parent_id, name: :ri_pp_fk

    assert_nothing_raised do
      @connection.disable_referential_integrity { }
    end

    fk_enforced = @connection.select_value(<<~SQL)
      SELECT conenforced FROM pg_constraint WHERE conname = 'ri_pp_fk'
    SQL
    assert fk_enforced, "FK between partitioned tables should be ENFORCED after the block"
  end

  def test_not_enforced_foreign_keys_remain_not_enforced_after_block
    skip unless @connection.supports_enforced_foreign_keys?

    @connection.add_foreign_key :ri_test_children, :ri_test_parents,
      column: :parent_id, name: :ri_test_fk, enforced: false

    @connection.disable_referential_integrity { }

    result = @connection.select_value(<<~SQL)
      SELECT c.conenforced
      FROM pg_constraint c
      WHERE c.conname = 'ri_test_fk'
    SQL

    assert_not result, "NOT ENFORCED foreign key should remain NOT ENFORCED after disable_referential_integrity block"
  end

  def test_enforced_foreign_keys_are_restored_to_enforced_after_block
    skip unless @connection.supports_enforced_foreign_keys?

    @connection.add_foreign_key :ri_test_children, :ri_test_parents, column: :parent_id, name: :ri_test_fk

    fk_enforced_during_block = nil
    @connection.disable_referential_integrity do
      fk_enforced_during_block = @connection.select_value(<<~SQL)
        SELECT c.conenforced
        FROM pg_constraint c
        WHERE c.conname = 'ri_test_fk'
      SQL
    end

    assert_not fk_enforced_during_block,
      "FK should be NOT ENFORCED inside the disable_referential_integrity block"

    fk_enforced_after = @connection.select_value(<<~SQL)
      SELECT c.conenforced
      FROM pg_constraint c
      WHERE c.conname = 'ri_test_fk'
    SQL

    assert fk_enforced_after,
      "FK should be restored to ENFORCED after disable_referential_integrity block"
  end

  def test_deferrable_foreign_keys_are_restored_after_block
    skip unless @connection.supports_enforced_foreign_keys?

    @connection.add_foreign_key :ri_test_children, :ri_test_parents,
      column: :parent_id, name: :ri_test_deferred_fk, deferrable: :deferred

    @connection.disable_referential_integrity { }

    condeferrable = @connection.select_value(<<~SQL)
      SELECT c.condeferrable FROM pg_constraint c WHERE c.conname = 'ri_test_deferred_fk'
    SQL
    condeferred = @connection.select_value(<<~SQL)
      SELECT c.condeferred FROM pg_constraint c WHERE c.conname = 'ri_test_deferred_fk'
    SQL

    assert condeferrable, "FK should remain DEFERRABLE after disable_referential_integrity block"
    assert condeferred, "FK should remain INITIALLY DEFERRED after disable_referential_integrity block"
  end

  def test_validated_foreign_keys_are_restored_after_block
    skip unless @connection.supports_enforced_foreign_keys?

    @connection.add_foreign_key :ri_test_children, :ri_test_parents,
      column: :parent_id, name: :ri_test_validated_fk

    convalidated_before = @connection.select_value(<<~SQL)
      SELECT c.convalidated FROM pg_constraint c WHERE c.conname = 'ri_test_validated_fk'
    SQL
    assert convalidated_before, "FK should be VALIDATED before disable_referential_integrity block"

    @connection.disable_referential_integrity { }

    convalidated_after = @connection.select_value(<<~SQL)
      SELECT c.convalidated FROM pg_constraint c WHERE c.conname = 'ri_test_validated_fk'
    SQL
    assert convalidated_after, "FK should be restored to VALIDATED after disable_referential_integrity block"
  end

  def test_non_fk_error_in_block_propagates_original_exception
    skip unless @connection.supports_enforced_foreign_keys?

    @connection.add_foreign_key :ri_test_children, :ri_test_parents, column: :parent_id, name: :ri_test_fk

    original_error = nil
    @connection.transaction do
      original_error = assert_raises(ActiveRecord::StatementInvalid) do
        @connection.disable_referential_integrity do
          @connection.execute("SELECT 1/0")  # aborts the transaction
        end
      end
      raise ActiveRecord::Rollback
    end

    assert_match(/division by zero/, original_error.message)

    conenforced = @connection.select_value(<<~SQL)
      SELECT conenforced FROM pg_constraint WHERE conname = 'ri_test_fk'
    SQL
    assert conenforced,
      "FK should be restored to ENFORCED after the outer transaction rolls back"
  end

  def test_disable_referential_integrity_raises_invalid_foreign_key_on_fk_violation
    skip unless @connection.supports_enforced_foreign_keys?

    @connection.add_foreign_key :ri_test_children, :ri_test_parents, column: :parent_id, name: :ri_test_fk

    assert_raises(ActiveRecord::InvalidForeignKey) do
      @connection.transaction do
        @connection.disable_referential_integrity do
          @connection.execute("INSERT INTO ri_test_children(parent_id) VALUES (999)")
        end
      end
    end
  end

  def test_on_delete_cascade_does_not_fire_when_not_enforced
    skip unless @connection.supports_enforced_foreign_keys?

    @connection.add_foreign_key :ri_test_children, :ri_test_parents,
      column: :parent_id, name: :ri_test_cascade_fk, on_delete: :cascade

    parent_model = Class.new(ActiveRecord::Base) { self.table_name = "ri_test_parents" }
    child_model  = Class.new(ActiveRecord::Base) { self.table_name = "ri_test_children" }

    parent = parent_model.create!
    child_model.create!(parent_id: parent.id)

    @connection.disable_referential_integrity do
      @connection.execute("DELETE FROM ri_test_parents WHERE id = #{parent.id}")
      assert child_model.exists?(parent_id: parent.id),
        "Child row must remain because ON DELETE CASCADE is suppressed under NOT ENFORCED"
      @connection.execute("INSERT INTO ri_test_parents (id) VALUES (#{parent.id})")
    end
  end

  def test_check_all_foreign_keys_valid_skips_not_enforced_constraints
    skip unless @connection.supports_enforced_foreign_keys?

    @connection.add_foreign_key :ri_test_children, :ri_test_parents,
      column: :parent_id, name: :ri_test_not_enforced_fk, enforced: false

    parent_model = Class.new(ActiveRecord::Base) { self.table_name = "ri_test_parents" }
    child_model  = Class.new(ActiveRecord::Base) { self.table_name = "ri_test_children" }

    parent_model.create!
    child_model.create!(parent_id: 999)

    assert_nothing_raised do
      @connection.check_all_foreign_keys_valid!
    end
  end

  def test_all_foreign_keys_valid_having_foreign_keys_in_multiple_schemas
    @connection.execute <<~SQL
      CREATE SCHEMA referential_integrity_test_schema;

      CREATE TABLE referential_integrity_test_schema.nodes (
        id          BIGSERIAL,
        parent_id   INT      NOT NULL,
        PRIMARY KEY(id),
        CONSTRAINT fk_parent_node FOREIGN KEY(parent_id)
                                  REFERENCES referential_integrity_test_schema.nodes(id)
      );
    SQL

    result = @connection.execute <<~SQL
      SELECT count(*) AS count
        FROM information_schema.table_constraints
       WHERE constraint_schema = 'referential_integrity_test_schema'
         AND constraint_type = 'FOREIGN KEY';
    SQL

    assert_equal 1, result.first["count"], "referential_integrity_test_schema should have 1 foreign key"
    @connection.check_all_foreign_keys_valid!
  ensure
    @connection.drop_schema "referential_integrity_test_schema", if_exists: true
  end

  def test_all_foreign_keys_valid_having_foreign_keys_with_partitioned_table
    @connection.execute <<~SQL
      CREATE TABLE table_referenced_by_partioned_table (
        id          BIGSERIAL,
        PRIMARY KEY(id)
      );

      CREATE TABLE partitioned_table_with_foreign_key (
        id          BIGSERIAL,
        company_id   INT      NOT NULL,
        PRIMARY KEY(company_id, id),
        CONSTRAINT fk_reference FOREIGN KEY(company_id)
                                  REFERENCES table_referenced_by_partioned_table(id)
      ) PARTITION BY LIST (company_id);

      CREATE TABLE partitioned_table_with_foreign_key_1 PARTITION OF partitioned_table_with_foreign_key FOR VALUES IN (1);
    SQL

    @connection.check_all_foreign_keys_valid!

    result = @connection.execute <<~SQL
      SELECT count(*) AS count
      FROM pg_constraint
      WHERE convalidated = false
        AND conrelid::regclass IN ('partitioned_table_with_foreign_key'::regclass, 'partitioned_table_with_foreign_key_1'::regclass);
    SQL

    assert_equal 0, result.first["count"]
  ensure
    @connection.drop_table "partitioned_table_with_foreign_key", if_exists: true, force: true
    @connection.drop_table "table_referenced_by_partioned_table", if_exists: true
  end

  private
    def assert_transaction_is_not_broken
      assert_equal 1, @connection.select_value("SELECT 1")
    end
end
