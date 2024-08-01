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
  end

  def teardown
    reset_connection
    if ActiveRecord::Base.lease_connection.is_a?(MissingSuperuserPrivileges)
      raise "MissingSuperuserPrivileges patch was not removed"
    end
  end

  def test_should_reraise_invalid_foreign_key_exception_and_show_warning
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
    @connection.extend MissingSuperuserPrivileges

    @connection.transaction do
      @connection.disable_referential_integrity do
        assert_transaction_is_not_broken
      end
      assert_transaction_is_not_broken
    end
  end

  def test_does_not_break_nested_transactions
    @connection.extend MissingSuperuserPrivileges

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
    @connection.extend ProgrammerMistake

    assert_raises ArgumentError do
      @connection.disable_referential_integrity { }
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

  private
    def assert_transaction_is_not_broken
      assert_equal 1, @connection.select_value("SELECT 1")
    end
end
