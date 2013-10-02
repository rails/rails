require "cases/helper"
require 'active_record/base'
require 'active_record/connection_adapters/postgresql_adapter'

module PostgresqlReferentialIntegritySupport
  def setup
    @connection = ActiveRecord::Base.connection
    @savepoint_id = 0
    @fk_id = 0

    @connection.create_table :fk_test_has_ut do |t|
    end

    @connection.execute <<END_SQL
      CREATE FUNCTION fk_test_has_ut_rollback() RETURNS trigger AS $fk_test_has_ut_rollback$
        BEGIN
          RAISE EXCEPTION 'cannot insert or update records in this table!';
          RETURN NEW;
        END;
      $fk_test_has_ut_rollback$ LANGUAGE plpgsql;
      CREATE TRIGGER fk_test_has_ut_trigger BEFORE INSERT OR UPDATE ON fk_test_has_ut
        FOR EACH ROW EXECUTE PROCEDURE fk_test_has_ut_rollback();
END_SQL
  end

  def teardown
    @connection.execute("DROP TRIGGER IF EXISTS fk_test_has_ut_trigger ON fk_test_has_ut")
    @connection.execute("DROP FUNCTION IF EXISTS fk_test_has_ut_rollback()")
    @connection.drop_table :fk_test_has_ut
  end

  def get_unique_savepoint_id
    @savepoint_id += 1
  end

  def attempt_block
    if @connection.open_transactions > 0
      savepoint_id = get_unique_savepoint_id
      @connection.create_savepoint("attempt_block_#{savepoint_id}")
    end

    begin
      yield
    ensure
      if @connection.open_transactions > 0
        begin
          @connection.release_savepoint("attempt_block_#{savepoint_id}")
        rescue ActiveRecord::StatementInvalid
          @connection.rollback_to_savepoint("attempt_block_#{savepoint_id}")
          @connection.release_savepoint("attempt_block_#{savepoint_id}")
        end
      end
    end
  end

  def get_unique_fk_id
    @fk_id += 1
  end

  def respect_referential_integrity
    fk_id = get_unique_fk_id
    @connection.execute "INSERT INTO fk_test_has_pk (id) VALUES (#{fk_id})"
    @connection.execute "INSERT INTO fk_test_has_fk (fk_id) VALUES (#{fk_id})"
  end

  def temporarily_violate_referential_integrity
    fk_id = get_unique_fk_id
    @connection.execute "INSERT INTO fk_test_has_fk (fk_id) VALUES (#{fk_id})"
    @connection.execute "INSERT INTO fk_test_has_pk (id) VALUES (#{fk_id})"
  end

  def persistently_violate_referential_integrity
    fk_id = get_unique_fk_id
    @connection.execute "INSERT INTO fk_test_has_fk (fk_id) VALUES (#{fk_id})"
  end

  def violate_user_trigger
    @connection.execute "INSERT INTO fk_test_has_ut (id) VALUES (DEFAULT)"
  end

  def abort_current_transaction
    @connection.execute "INSERT INTO non_existing_table (fk_id) VALUES (0)" rescue nil
  end

  def verify_transaction_depth(depth)
    assert_equal depth, @connection.open_transactions, "Transaction depth did not match"
  end

  def verify_referential_integrity_is_enabled
    attempt_block do
      assert_raises(ActiveRecord::InvalidForeignKey) { temporarily_violate_referential_integrity }
    end
  end

  def verify_user_trigger_is_enabled
    attempt_block do
      assert_raises(ActiveRecord::StatementInvalid) { violate_user_trigger }
    end
  end

  def verify_row_counts(options={})
    counts = Hash.new
    counts[:pk] = options.fetch(:pk, 0)
    counts[:fk] = options.fetch(:fk, counts[:pk])
    counts[:ut] = options.fetch(:ut, 0)

    counts.each do |name, count|
      assert_equal count, @connection.select_rows("SELECT COUNT(*) FROM fk_test_has_#{name}")[0][0].to_i,
        "Count of rows in fk_test_has_#{name} did not match"
    end
  end

  def without_superuser_privs
    current_user = @connection.select_rows("SELECT CURRENT_USER")[0][0]
    begin
      @connection.execute "CREATE ROLE temp_superuser SUPERUSER"
      @connection.execute "GRANT temp_superuser TO #{current_user}"
      @connection.execute "ALTER ROLE #{current_user} NOSUPERUSER"

      attempt_block { yield }
    ensure
      @connection.execute "SET ROLE temp_superuser"
      @connection.execute "ALTER ROLE #{current_user} SUPERUSER"
      @connection.execute "RESET ROLE"
      @connection.execute "DROP ROLE temp_superuser"
    end
  end
end

class PostgresqlReferentialIntegrityTestWithTransactionalFixtures < ActiveRecord::TestCase
  include PostgresqlReferentialIntegritySupport

  def verify_preconditions
    verify_transaction_depth 1
    verify_referential_integrity_is_enabled
    verify_user_trigger_is_enabled
    verify_row_counts pk: 0, ut: 0
  end

  def verify_postconditions(options={})
    verify_transaction_depth 1
    verify_referential_integrity_is_enabled
    verify_user_trigger_is_enabled
    verify_row_counts options.slice(:pk, :fk, :ut)
  end

  def test_temporarily_violate_referential_integrity
    verify_preconditions
    attempt_block do
      assert_raises(ActiveRecord::InvalidForeignKey) { temporarily_violate_referential_integrity }
    end
    verify_postconditions pk: 0, ut: 0
  end

  def test_violate_user_trigger
    verify_preconditions
    attempt_block do
      assert_raises(ActiveRecord::StatementInvalid) { violate_user_trigger }
    end
    verify_postconditions pk: 0, ut: 0
  end

  def test_disable_referential_integrity_as_superuser_with_supports_disable_referential_integrity_disabled
    def @connection.supports_disable_referential_integrity?
      false
    end

    verify_preconditions
    attempt_block do
      assert_raises(ActiveRecord::InvalidForeignKey) do
        @connection.disable_referential_integrity do
          temporarily_violate_referential_integrity
        end
      end
    end
    verify_postconditions pk: 0, ut: 0
  ensure
    @connection.singleton_class.send(:remove_method, :supports_disable_referential_integrity?)
  end

  def test_disable_referential_integrity_as_superuser_in_simple_transaction
    verify_preconditions
    assert_nothing_raised do
      @connection.disable_referential_integrity do
        temporarily_violate_referential_integrity
        violate_user_trigger
      end
    end
    verify_postconditions pk: 1, ut: 1
  end

  def test_disable_referential_integrity_as_superuser_in_nested_transaction
    verify_preconditions
    @connection.transaction do
      assert_nothing_raised do
        @connection.disable_referential_integrity do
          temporarily_violate_referential_integrity
          violate_user_trigger
        end
      end
    end
    verify_postconditions pk: 1, ut: 1
  end

  def test_disable_referential_integrity_as_superuser_in_simple_transaction_with_persistent_violation
    verify_preconditions
    assert_nothing_raised do
      @connection.disable_referential_integrity do
        respect_referential_integrity
        temporarily_violate_referential_integrity
        persistently_violate_referential_integrity
      end
    end
    verify_postconditions pk: 2, fk: 3
  end

  def test_disable_referential_integrity_as_superuser_in_nested_transaction_with_persistent_violation
    verify_preconditions
    @connection.transaction do
      assert_nothing_raised do
        @connection.disable_referential_integrity do
          respect_referential_integrity
          temporarily_violate_referential_integrity
          persistently_violate_referential_integrity
        end
      end
    end
    verify_postconditions pk: 2, fk: 3
  end

  def test_disable_referential_integrity_as_superuser_in_simple_transaction_with_nested_dri
    verify_preconditions
    assert_nothing_raised do
      @connection.disable_referential_integrity do
        temporarily_violate_referential_integrity
        violate_user_trigger
        @connection.disable_referential_integrity do
          temporarily_violate_referential_integrity
          violate_user_trigger
        end
        temporarily_violate_referential_integrity
        violate_user_trigger
      end
    end
    verify_postconditions pk: 3, ut: 3
  end

  def test_disable_referential_integrity_as_superuser_in_nested_transaction_with_nested_dri
    verify_preconditions
    @connection.transaction do
      assert_nothing_raised do
        @connection.disable_referential_integrity do
          temporarily_violate_referential_integrity
          violate_user_trigger
          @connection.disable_referential_integrity do
            temporarily_violate_referential_integrity
            violate_user_trigger
          end
          temporarily_violate_referential_integrity
          violate_user_trigger
        end
      end
    end
    verify_postconditions pk: 3, ut: 3
  end

  def test_disable_referential_integrity_as_superuser_in_simple_transaction_with_aborted_transaction
    verify_preconditions
    assert_nothing_raised do
      @connection.disable_referential_integrity do
        respect_referential_integrity
        temporarily_violate_referential_integrity
        violate_user_trigger
        abort_current_transaction
      end
    end
    verify_postconditions pk: 0, ut: 0
  end

  def test_disable_referential_integrity_as_superuser_in_nested_transaction_with_aborted_transaction
    verify_preconditions
    @connection.transaction do
      assert_nothing_raised do
        @connection.disable_referential_integrity do
          respect_referential_integrity
          temporarily_violate_referential_integrity
          violate_user_trigger
          abort_current_transaction
        end
      end
    end
    verify_postconditions pk: 0, ut: 0
  end

  def test_disable_referential_integrity_as_superuser_in_simple_transaction_with_malicious_exception
    verify_preconditions
    assert_raises(Exception) do
      @connection.disable_referential_integrity do
        temporarily_violate_referential_integrity
        violate_user_trigger
        raise Exception
      end
    end
    verify_postconditions pk: 1, ut: 1
  end

  def test_disable_referential_integrity_as_superuser_in_nested_transaction_with_malicious_exception
    verify_preconditions
    @connection.transaction do
      assert_raises(Exception) do
        @connection.disable_referential_integrity do
          temporarily_violate_referential_integrity
          violate_user_trigger
          raise Exception
        end
      end
    end
    verify_postconditions pk: 1, ut: 1
  end

  def test_disable_referential_integrity_as_superuser_in_simple_transaction_with_enclosed_rolledback_transaction
    verify_preconditions
    assert_nothing_raised do
      @connection.disable_referential_integrity do
        respect_referential_integrity
        temporarily_violate_referential_integrity
        violate_user_trigger
        @connection.transaction { raise ActiveRecord::Rollback }
        abort_current_transaction
      end
    end
    verify_postconditions pk: 0, ut: 0
  end

  def test_disable_referential_integrity_as_nonsuperuser_fails_in_simple_transaction
    verify_preconditions
    without_superuser_privs do
      assert_raises(ActiveRecord::InvalidForeignKey) do
        @connection.disable_referential_integrity do
          respect_referential_integrity
          violate_user_trigger
          temporarily_violate_referential_integrity
        end
      end
    end
    verify_postconditions pk: 0, ut: 0
  end

  def test_disable_referential_integrity_as_nonsuperuser_fails_in_nested_transaction
    verify_preconditions
    without_superuser_privs do
      @connection.transaction do
        assert_raises(ActiveRecord::InvalidForeignKey) do
          @connection.disable_referential_integrity do
            respect_referential_integrity
            violate_user_trigger
            temporarily_violate_referential_integrity
          end
        end
      end
    end
    verify_postconditions pk: 0, ut: 0
  end

  def test_disable_referential_integrity_as_nonsuperuser_disables_user_triggers_in_simple_transaction
    verify_preconditions
    without_superuser_privs do
      assert_nothing_raised do
        @connection.disable_referential_integrity do
          respect_referential_integrity
          violate_user_trigger
        end
      end
    end
    verify_postconditions pk: 1, ut: 1
  end

  def test_disable_referential_integrity_as_nonsuperuser_disables_user_triggers_in_nested_transaction
    verify_preconditions
    without_superuser_privs do
      @connection.transaction do
        assert_nothing_raised do
          @connection.disable_referential_integrity do
          respect_referential_integrity
          violate_user_trigger
          end
        end
      end
    end
    verify_postconditions pk: 1, ut: 1
  end

end


class PostgresqlReferentialIntegrityTestWithoutTransactionalFixtures < ActiveRecord::TestCase
  include PostgresqlReferentialIntegritySupport

  self.use_transactional_fixtures = false

  def verify_preconditions
    verify_transaction_depth 0
    verify_referential_integrity_is_enabled
    verify_user_trigger_is_enabled
    verify_row_counts pk: 0, ut: 0
  end

  def verify_postconditions(options={})
    verify_transaction_depth 0
    verify_referential_integrity_is_enabled
    verify_user_trigger_is_enabled
    verify_row_counts options.slice(:pk, :fk, :ut)
  end

  def teardown
    super
    @connection.execute "DELETE FROM fk_test_has_fk"
    @connection.execute "DELETE FROM fk_test_has_pk"
  end


  def test_disable_referential_integrity_as_superuser_outside_transaction
    verify_preconditions
    assert_nothing_raised do
      @connection.disable_referential_integrity do
        temporarily_violate_referential_integrity
      end
    end
    verify_postconditions pk: 1
  end

  def test_disable_referential_integrity_as_superuser_outside_transaction_with_persistent_violation
    verify_preconditions
    assert_nothing_raised do
      @connection.disable_referential_integrity do
        respect_referential_integrity
        temporarily_violate_referential_integrity
        persistently_violate_referential_integrity
        violate_user_trigger
      end
    end
    verify_postconditions pk: 2, fk: 3, ut: 1
  end

  def test_disable_referential_integrity_as_superuser_outside_transaction_with_nested_dri
    verify_preconditions
    assert_nothing_raised do
      @connection.disable_referential_integrity do
        temporarily_violate_referential_integrity
        violate_user_trigger
        @connection.disable_referential_integrity do
          temporarily_violate_referential_integrity
          violate_user_trigger
        end
        temporarily_violate_referential_integrity
        violate_user_trigger
      end
    end
    verify_postconditions pk: 3, ut: 3
  end

  def test_disable_referential_integrity_as_superuser_outside_transaction_with_aborted_transaction
    verify_preconditions
    assert_nothing_raised do
      @connection.disable_referential_integrity do
        temporarily_violate_referential_integrity
        violate_user_trigger
        abort_current_transaction
      end
    end
    verify_postconditions pk: 1, ut: 1
  end

  def test_disable_referential_integrity_as_superuser_outside_transaction_with_malicious_exception
    verify_preconditions
    assert_raises(Exception) do
      @connection.disable_referential_integrity do
        temporarily_violate_referential_integrity
        violate_user_trigger
        raise Exception
      end
    end
    verify_postconditions pk: 1, ut: 1
  end

  def test_disable_referential_integrity_as_nonsuperuser_fails_outside_transaction
    verify_preconditions
    without_superuser_privs do
      assert_raises(ActiveRecord::InvalidForeignKey) do
        @connection.disable_referential_integrity do
          respect_referential_integrity
          violate_user_trigger
          temporarily_violate_referential_integrity
        end
      end
    end
    verify_postconditions pk: 1, ut: 1
  end

  def test_disable_referential_integrity_as_nonsuperuser_disables_user_triggers_outside_transaction
    verify_preconditions
    without_superuser_privs do
      assert_nothing_raised do
        @connection.disable_referential_integrity do
          respect_referential_integrity
          violate_user_trigger
        end
      end
    end
    verify_postconditions pk: 1, ut: 1
  end

end
