# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "tempfile"

module ActiveRecord
  class QueryRoleResolverTest < ActiveRecord::TestCase
    self.use_transactional_tests = false

    fixtures :posts

    class ResolverWritingReadingBase < ActiveRecord::Base
      self.abstract_class = true
    end

    class ResolverWritingOnlyBase < ActiveRecord::Base
      self.abstract_class = true
    end

    def setup
      @old_query_role_resolver = ActiveRecord.query_role_resolver
      @old_pin_role_on_write = ActiveRecord.pin_role_on_write
      @old_writing_role = ActiveRecord.writing_role
      @old_reading_role = ActiveRecord.reading_role
      @tempfiles = []
      clear_role_pinning_state
    end

    def teardown
      ActiveRecord.query_role_resolver = @old_query_role_resolver
      ActiveRecord.pin_role_on_write = @old_pin_role_on_write
      ActiveRecord.writing_role = @old_writing_role
      ActiveRecord.reading_role = @old_reading_role
      clear_role_pinning_state

      ResolverWritingReadingBase.remove_connection if ResolverWritingReadingBase.connected?
      ResolverWritingOnlyBase.remove_connection if ResolverWritingOnlyBase.connected?

      @tempfiles.each do |file|
        file.close
        file.unlink
      end
    end

    def test_query_role_resolver_is_called_with_query_type_model_and_current_role
      configure_writing_and_reading(ResolverWritingReadingBase)

      captured = nil
      ActiveRecord.query_role_resolver = ->(query_type, model, current_role) do
        captured = [query_type, model, current_role]
        nil
      end

      ResolverWritingReadingBase.release_connection
      ResolverWritingReadingBase.with_connection(query_type: :read) { }

      assert_equal [:read, ResolverWritingReadingBase, :writing], captured
    end

    def test_read_queries_can_switch_to_reading_role_before_checkout
      configure_writing_and_reading(ResolverWritingReadingBase)

      ActiveRecord.query_role_resolver = ->(query_type, _model, current_role) do
        query_type == :read ? :reading : current_role
      end

      ResolverWritingReadingBase.with_connection(query_type: :read) do |connection|
        assert_equal :reading, connection.pool.role
      end

      ResolverWritingReadingBase.with_connection(query_type: :write) do |connection|
        assert_equal :writing, connection.pool.role
      end
    end

    def test_existing_lease_prevents_role_switching
      configure_writing_and_reading(ResolverWritingReadingBase)

      resolver_calls = 0
      ActiveRecord.query_role_resolver = ->(query_type, _model, _current_role) do
        resolver_calls += 1
        query_type == :read ? :reading : :writing
      end

      ResolverWritingReadingBase.with_connection(query_type: :write) do |connection|
        connection.transaction do
          ResolverWritingReadingBase.with_connection(query_type: :read) do |nested_connection|
            assert_equal :writing, nested_connection.pool.role
          end
        end
      end

      assert_equal 1, resolver_calls
    end

    def test_missing_resolved_pool_falls_back_to_current_pool
      configure_writing_only(ResolverWritingOnlyBase)

      ActiveRecord.query_role_resolver = ->(_query_type, _model, _current_role) { :reading }

      ResolverWritingOnlyBase.with_connection(query_type: :read) do |connection|
        assert_equal :writing, connection.pool.role
      end
    end

    def test_nil_resolver_preserves_existing_behavior
      configure_writing_and_reading(ResolverWritingReadingBase)

      ActiveRecord.query_role_resolver = nil

      ResolverWritingReadingBase.with_connection(query_type: :read) do |connection|
        assert_equal :writing, connection.pool.role
      end
    end

    def test_connected_to_context_is_visible_to_resolver
      configure_writing_and_reading(ResolverWritingReadingBase)

      captured_current_role = nil
      ActiveRecord.query_role_resolver = ->(_query_type, _model, current_role) do
        captured_current_role = current_role
        nil
      end

      ResolverWritingReadingBase.connected_to(role: :reading) do
        ResolverWritingReadingBase.with_connection(query_type: :read) do |connection|
          assert_equal :reading, connection.pool.role
        end
      end

      assert_equal :reading, captured_current_role
    end

    def test_query_operations_pass_query_type_to_with_connection
      query_types = []
      ActiveRecord.query_role_resolver = ->(query_type, _model, _current_role) do
        query_types << query_type
        nil
      end

      Post.release_connection
      Post.first

      Post.release_connection
      Post.find_by_sql("SELECT * FROM posts LIMIT 1")

      Post.release_connection
      Post.where(id: 1).pluck(:id)

      Post.release_connection
      Post.where(id: 1).update_all(title: "captured")

      assert_includes query_types, :read
      assert_includes query_types, :write
    end

    def test_role_pinning_pins_to_writing_after_write_with_duration
      configure_writing_and_reading(ResolverWritingReadingBase)
      ActiveRecord.pin_role_on_write = 2
      ActiveRecord.query_role_resolver = ->(query_type, _model, current_role) do
        query_type == :read ? :reading : current_role
      end

      monotonic_now = 100.0
      Process.stub(:clock_gettime, ->(_clock) { monotonic_now }) do
        with_role_pinning_scope do
          ResolverWritingReadingBase.with_connection(query_type: :read) do |connection|
            assert_equal :reading, connection.pool.role
          end

          ResolverWritingReadingBase.with_connection(query_type: :write) do |connection|
            assert_equal :writing, connection.pool.role
          end

          monotonic_now = 101.0
          ResolverWritingReadingBase.with_connection(query_type: :read) do |connection|
            assert_equal :writing, connection.pool.role
          end

          monotonic_now = 103.0
          ResolverWritingReadingBase.with_connection(query_type: :read) do |connection|
            assert_equal :reading, connection.pool.role
          end
        end
      end
    end

    def test_role_pinning_pins_for_entire_scope_when_true
      configure_writing_and_reading(ResolverWritingReadingBase)
      ActiveRecord.pin_role_on_write = true
      ActiveRecord.query_role_resolver = ->(query_type, _model, current_role) do
        query_type == :read ? :reading : current_role
      end

      with_role_pinning_scope do
        ResolverWritingReadingBase.with_connection(query_type: :read) do |connection|
          assert_equal :reading, connection.pool.role
        end

        ResolverWritingReadingBase.with_connection(query_type: :write) do |connection|
          assert_equal :writing, connection.pool.role
        end

        ResolverWritingReadingBase.with_connection(query_type: :read) do |connection|
          assert_equal :writing, connection.pool.role
        end
      end
    end

    def test_role_pinning_resets_between_executor_scopes
      configure_writing_and_reading(ResolverWritingReadingBase)
      ActiveRecord.pin_role_on_write = true
      ActiveRecord.query_role_resolver = ->(query_type, _model, current_role) do
        query_type == :read ? :reading : current_role
      end

      with_role_pinning_scope do
        ResolverWritingReadingBase.with_connection(query_type: :write) do |connection|
          assert_equal :writing, connection.pool.role
        end
      end

      with_role_pinning_scope do
        ResolverWritingReadingBase.with_connection(query_type: :read) do |connection|
          assert_equal :reading, connection.pool.role
        end
      end
    end

    def test_role_pinning_is_noop_when_disabled
      configure_writing_and_reading(ResolverWritingReadingBase)
      ActiveRecord.pin_role_on_write = nil
      ActiveRecord.query_role_resolver = ->(query_type, _model, current_role) do
        query_type == :read ? :reading : current_role
      end

      with_role_pinning_scope do
        ResolverWritingReadingBase.with_connection(query_type: :write) do |connection|
          assert_equal :writing, connection.pool.role
        end

        ResolverWritingReadingBase.with_connection(query_type: :read) do |connection|
          assert_equal :reading, connection.pool.role
        end
      end
    end

    def test_role_pinning_extends_on_subsequent_writes
      configure_writing_and_reading(ResolverWritingReadingBase)
      ActiveRecord.pin_role_on_write = 2
      ActiveRecord.query_role_resolver = ->(query_type, _model, current_role) do
        query_type == :read ? :reading : current_role
      end

      monotonic_now = 100.0
      Process.stub(:clock_gettime, ->(_clock) { monotonic_now }) do
        with_role_pinning_scope do
          ResolverWritingReadingBase.with_connection(query_type: :write) { }
          monotonic_now = 101.0
          ResolverWritingReadingBase.with_connection(query_type: :write) { }

          monotonic_now = 102.5
          ResolverWritingReadingBase.with_connection(query_type: :read) do |connection|
            assert_equal :writing, connection.pool.role
          end

          monotonic_now = 103.5
          ResolverWritingReadingBase.with_connection(query_type: :read) do |connection|
            assert_equal :reading, connection.pool.role
          end
        end
      end
    end

    def test_role_pinning_works_without_resolver
      configure_writing_and_reading(ResolverWritingReadingBase)
      ActiveRecord.pin_role_on_write = true
      ActiveRecord.query_role_resolver = nil

      with_role_pinning_scope do
        ResolverWritingReadingBase.with_connection(query_type: :write) { }

        assert_predicate ActiveRecord::RolePinning, :pinned?
        ResolverWritingReadingBase.with_connection(query_type: :read) do |connection|
          assert_equal :writing, connection.pool.role
        end
      end
    end

    private
      # Executes a block inside role-pinning executor hooks.
      #
      # @yield runs inside a simulated executor scope.
      # @return [Object] block return value.
      # @example
      #   with_role_pinning_scope { User.first }
      def with_role_pinning_scope
        was_enabled = ActiveRecord::RolePinning::ExecutorHooks.run
        yield
      ensure
        ActiveRecord::RolePinning::ExecutorHooks.complete(was_enabled)
      end

      # Clears all role-pinning state from isolated execution storage.
      #
      # @return [void]
      # @example
      #   clear_role_pinning_state
      def clear_role_pinning_state
        ActiveSupport::IsolatedExecutionState[ActiveRecord::RolePinning::PINNING_ENABLED_KEY] = nil
        ActiveSupport::IsolatedExecutionState[ActiveRecord::RolePinning::PINNED_UNTIL_KEY] = nil
      end

      # Configures a model class with separate writing and reading pools.
      #
      # @param klass [Class] an abstract Active Record class to configure.
      # @return [void]
      # @example
      #   configure_writing_and_reading(ResolverWritingReadingBase)
      def configure_writing_and_reading(klass)
        writing = create_tempfile
        reading = create_tempfile

        klass.connects_to database: {
          writing: { adapter: "sqlite3", database: writing.path },
          reading: { adapter: "sqlite3", database: reading.path }
        }
      end

      # Configures a model class with only a writing pool.
      #
      # @param klass [Class] an abstract Active Record class to configure.
      # @return [void]
      # @example
      #   configure_writing_only(ResolverWritingOnlyBase)
      def configure_writing_only(klass)
        writing = create_tempfile

        klass.connects_to database: {
          writing: { adapter: "sqlite3", database: writing.path }
        }
      end

      # Creates and tracks a tempfile so teardown can always clean it up.
      #
      # @return [Tempfile] an open temporary file.
      # @example
      #   db_file = create_tempfile
      #   db_file.path # => "/tmp/..."
      def create_tempfile
        file = Tempfile.open("query_role_resolver")
        @tempfiles << file
        file
      end
  end
end
