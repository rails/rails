require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class ConnectionHandlerTest < ActiveRecord::TestCase
      def setup
        @handler = ConnectionHandler.new
        @spec_name = "primary"
        @pool = @handler.establish_connection(ActiveRecord::Base.configurations["arunit"])
      end

      def test_establish_connection_uses_spec_name
        config = { "readonly" => { "adapter" => "sqlite3" } }
        resolver = ConnectionAdapters::ConnectionSpecification::Resolver.new(config)
        spec =   resolver.spec(:readonly)
        @handler.establish_connection(spec.to_hash)

        assert_not_nil @handler.retrieve_connection_pool("readonly")
      ensure
        @handler.remove_connection("readonly")
      end

      def test_establish_connection_using_3_levels_config
        previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "default_env"

        config = {
          "default_env" => {
            "readonly" => { "adapter" => "sqlite3", "database" => "db/readonly.sqlite3" },
            "primary"  => { "adapter" => "sqlite3", "database" => "db/primary.sqlite3" }
          },
          "another_env" => {
            "readonly" => { "adapter" => "sqlite3", "database" => "db/bad-readonly.sqlite3" },
            "primary"  => { "adapter" => "sqlite3", "database" => "db/bad-primary.sqlite3" }
          },
          "common" => { "adapter" => "sqlite3", "database" => "db/common.sqlite3" }
        }
        @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

        @handler.establish_connection(:common)
        @handler.establish_connection(:primary)
        @handler.establish_connection(:readonly)

        assert_not_nil pool = @handler.retrieve_connection_pool("readonly")
        assert_equal "db/readonly.sqlite3", pool.spec.config[:database]

        assert_not_nil pool = @handler.retrieve_connection_pool("primary")
        assert_equal "db/primary.sqlite3", pool.spec.config[:database]

        assert_not_nil pool = @handler.retrieve_connection_pool("common")
        assert_equal "db/common.sqlite3", pool.spec.config[:database]
      ensure
        ActiveRecord::Base.configurations = @prev_configs
        ENV["RAILS_ENV"] = previous_env
      end

      def test_establish_connection_using_two_level_configurations
        config = { "development" => { "adapter" => "sqlite3", "database" => "db/primary.sqlite3" } }
        @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

        @handler.establish_connection(:development)

        assert_not_nil pool = @handler.retrieve_connection_pool("development")
        assert_equal "db/primary.sqlite3", pool.spec.config[:database]
      ensure
        ActiveRecord::Base.configurations = @prev_configs
      end

      def test_establish_connection_using_top_level_key_in_two_level_config
        config = {
          "development" => { "adapter" => "sqlite3", "database" => "db/primary.sqlite3" },
          "development_readonly" => { "adapter" => "sqlite3", "database" => "db/readonly.sqlite3" }
        }
        @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

        @handler.establish_connection(:development_readonly)

        assert_not_nil pool = @handler.retrieve_connection_pool("development_readonly")
        assert_equal "db/readonly.sqlite3", pool.spec.config[:database]
      ensure
        ActiveRecord::Base.configurations = @prev_configs
      end

      def test_retrieve_connection
        assert @handler.retrieve_connection(@spec_name)
      end

      def test_active_connections?
        assert !@handler.active_connections?
        assert @handler.retrieve_connection(@spec_name)
        assert @handler.active_connections?
        @handler.clear_active_connections!
        assert !@handler.active_connections?
      end

      def test_retrieve_connection_pool
        assert_not_nil @handler.retrieve_connection_pool(@spec_name)
      end

      def test_retrieve_connection_pool_with_invalid_id
        assert_nil @handler.retrieve_connection_pool("foo")
      end

      def test_connection_pools
        assert_equal([@pool], @handler.connection_pools)
      end

      if Process.respond_to?(:fork)
        def test_connection_pool_per_pid
          object_id = ActiveRecord::Base.connection.object_id

          rd, wr = IO.pipe
          rd.binmode
          wr.binmode

          pid = fork {
            rd.close
            wr.write Marshal.dump ActiveRecord::Base.connection.object_id
            wr.close
            exit!
          }

          wr.close

          Process.waitpid pid
          assert_not_equal object_id, Marshal.load(rd.read)
          rd.close
        end

        def test_retrieve_connection_pool_copies_schema_cache_from_ancestor_pool
          @pool.schema_cache = @pool.connection.schema_cache
          @pool.schema_cache.add("posts")

          rd, wr = IO.pipe
          rd.binmode
          wr.binmode

          pid = fork {
            rd.close
            pool = @handler.retrieve_connection_pool(@spec_name)
            wr.write Marshal.dump pool.schema_cache.size
            wr.close
            exit!
          }

          wr.close

          Process.waitpid pid
          assert_equal @pool.schema_cache.size, Marshal.load(rd.read)
          rd.close
        end

        def test_pool_from_any_process_for_uses_most_recent_spec
          skip unless current_adapter?(:SQLite3Adapter)

          file = Tempfile.new "lol.sqlite3"

          rd, wr = IO.pipe
          rd.binmode
          wr.binmode

          pid = fork do
            ActiveRecord::Base.configurations["arunit"]["database"] = file.path
            ActiveRecord::Base.establish_connection(:arunit)

            pid2 = fork do
              wr.write ActiveRecord::Base.connection_config[:database]
              wr.close
            end

            Process.waitpid pid2
          end

          Process.waitpid pid

          wr.close

          assert_equal file.path, rd.read

          rd.close
        ensure
          if file
            file.close
            file.unlink
          end
        end

        def test_a_class_using_custom_pool_and_switching_back_to_primary
          klass2 = Class.new(Base) { def self.name; "klass2"; end }

          assert_equal klass2.connection.object_id, ActiveRecord::Base.connection.object_id

          pool = klass2.establish_connection(ActiveRecord::Base.connection_pool.spec.config)
          assert_equal klass2.connection.object_id, pool.connection.object_id
          refute_equal klass2.connection.object_id, ActiveRecord::Base.connection.object_id

          klass2.remove_connection

          assert_equal klass2.connection.object_id, ActiveRecord::Base.connection.object_id
        end

        def test_connection_specification_name_should_fallback_to_parent
          klassA = Class.new(Base)
          klassB = Class.new(klassA)

          assert_equal klassB.connection_specification_name, klassA.connection_specification_name
          klassA.connection_specification_name = "readonly"
          assert_equal "readonly", klassB.connection_specification_name
        end

        def test_remove_connection_should_not_remove_parent
          klass2 = Class.new(Base) { def self.name; "klass2"; end }
          klass2.remove_connection
          refute_nil ActiveRecord::Base.connection.object_id
          assert_equal klass2.connection.object_id, ActiveRecord::Base.connection.object_id
        end
      end
    end
  end
end
