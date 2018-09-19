# frozen_string_literal: true

module ActiveRecord
  module TestFixtures
    extend ActiveSupport::Concern

    def before_setup # :nodoc:
      setup_fixtures
      super
    end

    def after_teardown # :nodoc:
      super
      teardown_fixtures
    end

    included do
      class_attribute :fixture_path, instance_writer: false
      class_attribute :fixture_table_names, default: Hash.new { |h, k| h[k] = [] }
      class_attribute :fixture_class_names, default: {}
      class_attribute :use_transactional_tests, default: true
      class_attribute :use_instantiated_fixtures, default: false # true, false, or :no_instances
      class_attribute :pre_loaded_fixtures, default: false
      class_attribute :config, default: ActiveRecord::Base
      class_attribute :lock_threads, default: true
    end

    module ClassMethods
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

      def fixtures(*fixture_set_names, database: :all)
        parent_fixture_table_names = fixture_table_names
        self.fixture_table_names = Hash.new { |h, k| h[k] = [] }
        database = database == :all ? nil : database.to_s
        environment = ActiveRecord::ConnectionHandling::DEFAULT_ENV.call
        configs = ActiveRecord::Base.configurations.configs_for(env_name: environment, spec_name: database)
        Array(configs).each do |db_config|
          child_fixture_table_names = all_fixtures_for(db_config)
          child_fixture_table_names &= fixture_set_names.flatten.map(&:to_s) unless fixture_set_names.first == :all

          config_fixture_table_names = parent_fixture_table_names[db_config.spec_name] + child_fixture_table_names
          fixture_table_names[db_config.spec_name] |= config_fixture_table_names
          setup_fixture_accessors(db_config, child_fixture_table_names)
        end
      end

      def setup_fixture_accessors(db_config, fixture_set_names = nil)
        fixture_set_names = Array(fixture_set_names || fixture_table_names[db_config.spec_name])
        methods = Module.new do
          fixture_set_names.each do |fs_name|
            fs_name = fs_name.to_s
            source = db_config.spec_name
            prefix = source == "primary" ? nil : source
            accessor_name = [prefix, fs_name.tr("/", "_")].compact.join("_")

            define_method(accessor_name) do |*fixture_names|
              force_reload = fixture_names.pop if fixture_names.last == true || fixture_names.last == :reload
              return_single_record = fixture_names.size == 1
              fixture_names = @loaded_fixtures[source][fs_name].fixtures.keys if fixture_names.empty?

              @fixture_cache[source] ||= {}
              @fixture_cache[source][fs_name] ||= {}

              instances = fixture_names.map do |f_name|
                f_name = f_name.to_s if f_name.is_a?(Symbol)
                @fixture_cache[source][fs_name].delete(f_name) if force_reload

                if @loaded_fixtures[source][fs_name][f_name]
                  connection = @fixture_connections[db_config.spec_name.to_sym]
                  @fixture_cache[source][fs_name][f_name] ||= @loaded_fixtures[source][fs_name][f_name].find
                else
                  raise StandardError, "No fixture named '#{f_name}' found for fixture set '#{fs_name}'"
                end
              end

              return_single_record ? instances.first : instances
            end
            private accessor_name
          end
        end
        include methods
      end

      def uses_transaction(*methods)
        @uses_transaction = [] unless defined?(@uses_transaction)
        @uses_transaction.concat methods.map(&:to_s)
      end

      def uses_transaction?(method)
        @uses_transaction = [] unless defined?(@uses_transaction)
        @uses_transaction.include?(method.to_s)
      end

      private

        def all_fixtures_for(db_config)
          paths = db_config.fixtures_path || fixture_path
          raise StandardError, "No fixture path found. Please set `#{self}.fixture_path`." if paths.blank?
          fixture_set_names = Dir["#{fixture_path}/{**,*}/*.{yml}"].uniq
          Array(paths).flat_map do |path|
            Dir["#{path}/{**,*}/*.{yml}"].uniq.map do |fixture|
              fixture[(path.to_s.size + 1)..-5]
            end
          end
        end
    end

    def run_in_transaction?
      use_transactional_tests &&
        !self.class.uses_transaction?(method_name)
    end

    def setup_fixtures(config = ActiveRecord::Base)
      if pre_loaded_fixtures && !use_transactional_tests
        raise RuntimeError, "pre_loaded_fixtures requires use_transactional_tests"
      end

      @fixture_cache = {}
      @fixture_connections = {}
      @@already_loaded_fixtures ||= {}
      @connection_subscriber = nil

      # Load fixtures once and begin transaction.
      if run_in_transaction?
        if @@already_loaded_fixtures[self.class]
          @loaded_fixtures = @@already_loaded_fixtures[self.class]
        else
          @loaded_fixtures = load_fixtures(config)
          @@already_loaded_fixtures[self.class] = @loaded_fixtures
        end

        # Begin transactions for connections already established
        @fixture_connections = enlist_fixture_connections
        @fixture_connections.each do |_spec_name, connection|
          connection.begin_transaction joinable: false, _lazy: false
          connection.pool.lock_thread = true if lock_threads
        end

        # When connections are established in the future, begin a transaction too
        @connection_subscriber = ActiveSupport::Notifications.subscribe("!connection.active_record") do |_, _, _, _, payload|
          spec_name = payload[:spec_name] if payload.key?(:spec_name)

          if spec_name
            begin
              connection = ActiveRecord::Base.connection_handler.retrieve_connection(spec_name)
            rescue ConnectionNotEstablished
              connection = nil
            end

            if connection && !@fixture_connections.values.include?(connection)
              connection.begin_transaction joinable: false, _lazy: false
              connection.pool.lock_thread = true if lock_threads
              @fixture_connections[spec_name] = connection
            end
          end
        end

      # Load fixtures for every test.
      else
        ActiveRecord::FixtureSet.reset_cache
        @@already_loaded_fixtures[self.class] = nil
        @loaded_fixtures = load_fixtures(config)
      end

      # Instantiate fixtures for every test if requested.
      instantiate_fixtures if use_instantiated_fixtures
    end

    def teardown_fixtures
      # Rollback changes if a transaction is active.
      if run_in_transaction?
        ActiveSupport::Notifications.unsubscribe(@connection_subscriber) if @connection_subscriber
        @fixture_connections.values.each do |connection|
          connection.rollback_transaction if connection.transaction_open?
          connection.pool.lock_thread = false
        end
        @fixture_connections.clear
      else
        ActiveRecord::FixtureSet.reset_cache
      end

      ActiveRecord::Base.clear_active_connections!
    end

    def enlist_fixture_connections
      setup_shared_connection_pool

      ActiveRecord::Base.connection_handler.connection_pool_list.map do |list|
        [list.spec.name, list.connection]
      end.to_h
    end

    private

      # Shares the writing connection pool with connections on
      # other handlers.
      #
      # In an application with a primary and replica the test fixtures
      # need to share a connection pool so that the reading connection
      # can see data in the open transaction on the writing connection.
      def setup_shared_connection_pool
        writing_handler = ActiveRecord::Base.connection_handler

        ActiveRecord::Base.connection_handlers.values.each do |handler|
          if handler != writing_handler
            handler.connection_pool_list.each do |pool|
              name = pool.spec.name
              writing_connection = writing_handler.retrieve_connection_pool(name)
              handler.send(:owner_to_pool)[name] = writing_connection
            end
          end
        end
      end

      def load_fixtures(config)
        environment = ActiveRecord::ConnectionHandling::DEFAULT_ENV.call
        all_fixtures = config.configurations.configs_for(env_name: environment).map do |db_config|
          connection = @fixture_connections[db_config.spec_name.to_sym]
          fixtures = create_fixtures_for(db_config, connection, config)
          [db_config.spec_name, Hash[fixtures.map { |f| [f.name, f] }]]
        end

        Hash[all_fixtures]
      end

      def create_fixtures_for(db_config, connection, config)
        ActiveRecord::FixtureSet.create_fixtures(
          config.connection.fixtures_path,
          fixture_table_names[db_config.spec_name],
          fixture_class_names,
          connection,
          config,

        )
      end

      def instantiate_fixtures
        if pre_loaded_fixtures
          raise RuntimeError, "Load fixtures before instantiating them." if ActiveRecord::FixtureSet.all_loaded_fixtures.empty?
          ActiveRecord::FixtureSet.instantiate_all_loaded_fixtures(self, load_instances?)
        else
          raise RuntimeError, "Load fixtures before instantiating them." if @loaded_fixtures.nil?
          @loaded_fixtures.each_value do |fixture_sets|
            fixture_sets.each_value do |fixture_set|
              ActiveRecord::FixtureSet.instantiate_fixtures(self, fixture_set, load_instances?)
            end
          end
        end
      end

      def load_instances?
        use_instantiated_fixtures != :no_instances
      end
  end
end
