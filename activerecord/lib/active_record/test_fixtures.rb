# frozen_string_literal: true

require "active_support/core_ext/enumerable"

module ActiveRecord
  module TestFixtures
    extend ActiveSupport::Concern

    def before_setup # :nodoc:
      setup_fixtures
      super
    end

    def after_teardown # :nodoc:
      super
    ensure
      teardown_fixtures
    end

    included do
      ##
      # :singleton-method: fixture_paths
      #
      # Returns the ActiveRecord::FixtureSet collection

      ##
      # :singleton-method: fixture_paths=
      #
      # :call-seq:
      #   fixture_paths=(fixture_paths)
      class_attribute :fixture_paths, instance_writer: false, default: []
      class_attribute :fixture_table_names, default: []
      class_attribute :fixture_class_names, default: {}
      class_attribute :use_transactional_tests, default: true
      class_attribute :use_instantiated_fixtures, default: false # true, false, or :no_instances
      class_attribute :pre_loaded_fixtures, default: false
      class_attribute :lock_threads, default: true
      class_attribute :fixture_sets, default: {}
      class_attribute :database_transactions_config, default: {}

      ActiveSupport.run_load_hooks(:active_record_fixtures, self)
    end

    module ClassMethods
      # Do not use transactional tests for the given database. This overrides
      # the default setting as defined by `use_transactional_tests`, which
      # applies to all database connection pools not explicitly configured here.
      def skip_transactional_tests_for_database(database_name)
        use_transactional_tests_for_database(database_name, false)
      end

      # Enable or disable transactions per database. This overrides the default
      # setting as defined by `use_transactional_tests`, which applies to all
      # database connection pools not explicitly configured here.
      def use_transactional_tests_for_database(database_name, enabled = true)
        self.database_transactions_config = database_transactions_config.merge(database_name => enabled)
      end

      # Sets the model class for a fixture when the class name cannot be inferred from the fixture name.
      #
      # Examples:
      #
      #   set_fixture_class some_fixture:        SomeModel,
      #                     'namespaced/fixture' => Another::Model
      #
      # The keys must be the fixture names, that coincide with the short paths to the fixture files.
      def set_fixture_class(class_names = {})
        self.fixture_class_names = fixture_class_names.merge(class_names.stringify_keys)
      end

      def fixtures(*fixture_set_names)
        if fixture_set_names.first == :all
          raise StandardError, "No fixture path found. Please set `#{self}.fixture_paths`." if fixture_paths.blank?
          fixture_set_names = fixture_paths.flat_map do |path|
            names = Dir[::File.join(path, "{**,*}/*.{yml}")].uniq
            names.reject! { |f| f.start_with?(file_fixture_path.to_s) } if defined?(file_fixture_path) && file_fixture_path
            names.map! { |f| f[path.to_s.size..-5].delete_prefix("/") }
          end.uniq
        else
          fixture_set_names = fixture_set_names.flatten.map(&:to_s)
        end

        self.fixture_table_names = (fixture_table_names | fixture_set_names).sort
        setup_fixture_accessors(fixture_set_names)
      end

      def setup_fixture_accessors(fixture_set_names = nil)
        fixture_set_names = Array(fixture_set_names || fixture_table_names)
        unless fixture_set_names.empty?
          self.fixture_sets = fixture_sets.dup
          fixture_set_names.each do |fs_name|
            key = fs_name.to_s.include?("/") ? -fs_name.to_s.tr("/", "_") : fs_name
            key = -key.to_s if key.is_a?(Symbol)
            fs_name = -fs_name.to_s if fs_name.is_a?(Symbol)
            fixture_sets[key] = fs_name
          end
        end
      end

      # Prevents automatically wrapping each specified test in a transaction,
      # to allow application logic transactions to be tested in a top-level
      # (non-nested) context.
      def uses_transaction(*methods)
        @uses_transaction = [] unless defined?(@uses_transaction)
        @uses_transaction.concat methods.map(&:to_s)
      end

      def uses_transaction?(method)
        @uses_transaction = [] unless defined?(@uses_transaction)
        @uses_transaction.include?(method.to_s)
      end
    end

    # Generic fixture accessor for fixture names that may conflict with other methods.
    #
    #   assert_equal "Ruby on Rails", web_sites(:rubyonrails).name
    #   assert_equal "Ruby on Rails", fixture(:web_sites, :rubyonrails).name
    def fixture(fixture_set_name, *fixture_names)
      active_record_fixture(fixture_set_name, *fixture_names)
    end

    private
      def run_in_transaction?
        has_explicit_config = database_transactions_config.any? { |_, enabled| enabled }
        (use_transactional_tests || has_explicit_config) &&
          !self.class.uses_transaction?(name)
      end

      def setup_fixtures(config = ActiveRecord::Base)
        if pre_loaded_fixtures && !use_transactional_tests
          raise RuntimeError, "pre_loaded_fixtures requires use_transactional_tests"
        end

        @fixture_cache = {}
        @fixture_cache_key = [self.class.fixture_table_names.dup, self.class.fixture_paths.dup, self.class.fixture_class_names.dup]
        @fixture_connection_pools = []
        @@already_loaded_fixtures ||= {}
        @connection_subscriber = nil
        @saved_pool_configs = Hash.new { |hash, key| hash[key] = {} }

        if run_in_transaction?
          # Load fixtures once and begin transaction.
          @loaded_fixtures = @@already_loaded_fixtures[@fixture_cache_key]
          unless @loaded_fixtures
            @@already_loaded_fixtures.clear
            @loaded_fixtures = @@already_loaded_fixtures[@fixture_cache_key] = load_fixtures(config)
          end

          setup_transactional_fixtures
        else
          # Load fixtures for every test.
          ActiveRecord::FixtureSet.reset_cache
          invalidate_already_loaded_fixtures
          @loaded_fixtures = load_fixtures(config)
        end
        setup_asynchronous_queries_session

        # Instantiate fixtures for every test if requested.
        instantiate_fixtures if use_instantiated_fixtures
      end

      def teardown_fixtures
        teardown_asynchronous_queries_session

        # Rollback changes if a transaction is active.
        if run_in_transaction?
          teardown_transactional_fixtures
        else
          ActiveRecord::FixtureSet.reset_cache
          invalidate_already_loaded_fixtures
        end

        ActiveRecord::Base.connection_handler.clear_active_connections!(:all)
      end

      def setup_asynchronous_queries_session
        @_async_queries_session = ActiveRecord::Base.asynchronous_queries_tracker.start_session
      end

      def teardown_asynchronous_queries_session
        ActiveRecord::Base.asynchronous_queries_tracker.finalize_session(true) if @_async_queries_session
      end

      def invalidate_already_loaded_fixtures
        @@already_loaded_fixtures.clear
      end

      def transactional_tests_for_pool?(pool)
        database_transactions_config.fetch(pool.db_config.name.to_sym, use_transactional_tests)
      end

      def setup_transactional_fixtures
        setup_shared_connection_pool

        # Begin transactions for connections already established
        @fixture_connection_pools = ActiveRecord::Base.connection_handler.connection_pool_list(:writing)

        # Filter to pools that want to use transactions
        @fixture_connection_pools.select! { |pool| transactional_tests_for_pool?(pool) }

        @fixture_connection_pools.each do |pool|
          pool.pin_connection!(lock_threads)
          pool.lease_connection
        end

        # When connections are established in the future, begin a transaction too
        @connection_subscriber = ActiveSupport::Notifications.subscribe("!connection.active_record") do |_, _, _, _, payload|
          connection_name = payload[:connection_name] if payload.key?(:connection_name)
          shard = payload[:shard] if payload.key?(:shard)

          if connection_name
            pool = ActiveRecord::Base.connection_handler.retrieve_connection_pool(connection_name, shard: shard)
            if pool
              setup_shared_connection_pool

              # Don't begin a transaction if we've already done so, or are not using them for this pool
              if !@fixture_connection_pools.include?(pool) && transactional_tests_for_pool?(pool)
                pool.pin_connection!(lock_threads)
                pool.lease_connection
                @fixture_connection_pools << pool
              end
            end
          end
        end
      end

      def teardown_transactional_fixtures
        ActiveSupport::Notifications.unsubscribe(@connection_subscriber) if @connection_subscriber

        unless @fixture_connection_pools.map(&:unpin_connection!).all?
          # Something caused the transaction to be committed or rolled back
          # We can no longer trust the database is in a clean state.
          @@already_loaded_fixtures.clear
        end
        @fixture_connection_pools.clear
        teardown_shared_connection_pool
      end

      # Shares the writing connection pool with connections on
      # other handlers.
      #
      # In an application with a primary and replica the test fixtures
      # need to share a connection pool so that the reading connection
      # can see data in the open transaction on the writing connection.
      def setup_shared_connection_pool
        handler = ActiveRecord::Base.connection_handler

        handler.connection_pool_names.each do |name|
          pool_manager = handler.send(:connection_name_to_pool_manager)[name]
          pool_manager.shard_names.each do |shard_name|
            writing_pool_config = pool_manager.get_pool_config(ActiveRecord.writing_role, shard_name)
            @saved_pool_configs[name][shard_name] ||= {}
            pool_manager.role_names.each do |role|
              next unless pool_config = pool_manager.get_pool_config(role, shard_name)
              next if pool_config == writing_pool_config

              @saved_pool_configs[name][shard_name][role] = pool_config
              pool_manager.set_pool_config(role, shard_name, writing_pool_config)
            end
          end
        end
      end

      def teardown_shared_connection_pool
        handler = ActiveRecord::Base.connection_handler

        @saved_pool_configs.each_pair do |name, shards|
          pool_manager = handler.send(:connection_name_to_pool_manager)[name]
          shards.each_pair do |shard_name, roles|
            roles.each_pair do |role, pool_config|
              next unless pool_manager.get_pool_config(role, shard_name)

              pool_manager.set_pool_config(role, shard_name, pool_config)
            end
          end
        end

        @saved_pool_configs.clear
      end

      def load_fixtures(config)
        ActiveRecord::FixtureSet.create_fixtures(fixture_paths, fixture_table_names, fixture_class_names, config).index_by(&:name)
      end

      def instantiate_fixtures
        if pre_loaded_fixtures
          raise RuntimeError, "Load fixtures before instantiating them." if ActiveRecord::FixtureSet.all_loaded_fixtures.empty?
          ActiveRecord::FixtureSet.instantiate_all_loaded_fixtures(self, load_instances?)
        else
          raise RuntimeError, "Load fixtures before instantiating them." if @loaded_fixtures.nil?
          @loaded_fixtures.each_value do |fixture_set|
            ActiveRecord::FixtureSet.instantiate_fixtures(self, fixture_set, load_instances?)
          end
        end
      end

      def load_instances?
        use_instantiated_fixtures != :no_instances
      end

      def method_missing(method, ...)
        if fixture_sets.key?(method.name)
          active_record_fixture(method, ...)
        else
          super
        end
      end

      def respond_to_missing?(method, include_private = false)
        if include_private && fixture_sets.key?(method.name)
          true
        else
          super
        end
      end

      def active_record_fixture(fixture_set_name, *fixture_names)
        if fs_name = fixture_sets[fixture_set_name.name]
          access_fixture(fs_name, *fixture_names)
        else
          raise StandardError, "No fixture set named '#{fixture_set_name.inspect}'"
        end
      end

      def access_fixture(fs_name, *fixture_names)
        force_reload = fixture_names.pop if fixture_names.last == true || fixture_names.last == :reload
        return_single_record = fixture_names.size == 1

        fixture_names = @loaded_fixtures[fs_name].fixtures.keys if fixture_names.empty?
        @fixture_cache[fs_name] ||= {}

        instances = fixture_names.map do |f_name|
          f_name = f_name.to_s if f_name.is_a?(Symbol)
          @fixture_cache[fs_name].delete(f_name) if force_reload

          if @loaded_fixtures[fs_name][f_name]
            @fixture_cache[fs_name][f_name] ||= @loaded_fixtures[fs_name][f_name].find
          else
            raise StandardError, "No fixture named '#{f_name}' found for fixture set '#{fs_name}'"
          end
        end

        return_single_record ? instances.first : instances
      end
  end
end
