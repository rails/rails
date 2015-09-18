require 'cases/helper'

if current_adapter?(:MysqlAdapter, :Mysql2Adapter)
module ActiveRecord
  class MysqlDBCreateTest < ActiveRecord::TestCase
    def setup
      @connection    = stub(:create_database => true)
      @configuration = {
        'adapter'  => 'mysql',
        'database' => 'my-app-db'
      }

      ActiveRecord::Base.stubs(:connection).returns(@connection)
      ActiveRecord::Base.stubs(:establish_connection).returns(true)
    end

    def test_establishes_connection_without_database
      ActiveRecord::Base.expects(:establish_connection).
        with('adapter' => 'mysql', 'database' => nil)

      ActiveRecord::Tasks::DatabaseTasks.create @configuration
    end

    def test_creates_database_with_default_encoding_and_collation
      @connection.expects(:create_database).
        with('my-app-db', charset: 'utf8', collation: 'utf8_unicode_ci')

      ActiveRecord::Tasks::DatabaseTasks.create @configuration
    end

    def test_creates_database_with_given_encoding_and_default_collation
      @connection.expects(:create_database).
        with('my-app-db', charset: 'utf8', collation: 'utf8_unicode_ci')

      ActiveRecord::Tasks::DatabaseTasks.create @configuration.merge('encoding' => 'utf8')
    end

    def test_creates_database_with_given_encoding_and_no_collation
      @connection.expects(:create_database).
        with('my-app-db', charset: 'latin1')

      ActiveRecord::Tasks::DatabaseTasks.create @configuration.merge('encoding' => 'latin1')
    end

    def test_creates_database_with_given_collation_and_no_encoding
      @connection.expects(:create_database).
        with('my-app-db', collation: 'latin1_swedish_ci')

      ActiveRecord::Tasks::DatabaseTasks.create @configuration.merge('collation' => 'latin1_swedish_ci')
    end

    def test_establishes_connection_to_database
      ActiveRecord::Base.expects(:establish_connection).with(@configuration)

      ActiveRecord::Tasks::DatabaseTasks.create @configuration
    end

    def test_create_when_database_exists_outputs_info_to_stderr
      $stderr.expects(:puts).with("my-app-db already exists").once

      ActiveRecord::Base.connection.stubs(:create_database).raises(
        ActiveRecord::StatementInvalid.new("Can't create database 'dev'; database exists:")
      )

      ActiveRecord::Tasks::DatabaseTasks.create @configuration
    end
  end

  if current_adapter?(:MysqlAdapter)
    class MysqlDBCreateAsRootTest < ActiveRecord::TestCase
      def setup
        @connection    = stub("Connection", create_database: true)
        @error         = Mysql::Error.new "Invalid permissions"
        @configuration = {
          'adapter'  => 'mysql',
          'database' => 'my-app-db',
          'username' => 'pat',
          'password' => 'wossname'
        }

        $stdin.stubs(:gets).returns("secret\n")
        $stdout.stubs(:print).returns(nil)
        @error.stubs(:errno).returns(1045)
        ActiveRecord::Base.stubs(:connection).returns(@connection)
        ActiveRecord::Base.stubs(:establish_connection).
          raises(@error).
          then.returns(true)
      end

      if defined?(::Mysql)
        def test_root_password_is_requested
          assert_permissions_granted_for "pat"
          $stdin.expects(:gets).returns("secret\n")

          ActiveRecord::Tasks::DatabaseTasks.create @configuration
        end
      end

      def test_connection_established_as_root
        assert_permissions_granted_for "pat"
        ActiveRecord::Base.expects(:establish_connection).with(
          'adapter'  => 'mysql',
          'database' => nil,
          'username' => 'root',
          'password' => 'secret'
        )

        ActiveRecord::Tasks::DatabaseTasks.create @configuration
      end

      def test_database_created_by_root
        assert_permissions_granted_for "pat"
        @connection.expects(:create_database).
          with('my-app-db', :charset => 'utf8', :collation => 'utf8_unicode_ci')

        ActiveRecord::Tasks::DatabaseTasks.create @configuration
      end

      def test_grant_privileges_for_normal_user
        assert_permissions_granted_for "pat"
        ActiveRecord::Tasks::DatabaseTasks.create @configuration
      end

      def test_do_not_grant_privileges_for_root_user
        @configuration['username'] = 'root'
        @configuration['password'] = ''
        ActiveRecord::Tasks::DatabaseTasks.create @configuration
      end

      def test_connection_established_as_normal_user
        assert_permissions_granted_for "pat"
        ActiveRecord::Base.expects(:establish_connection).returns do
          ActiveRecord::Base.expects(:establish_connection).with(
            'adapter'  => 'mysql',
            'database' => 'my-app-db',
            'username' => 'pat',
            'password' => 'secret'
          )

          raise @error
        end

        ActiveRecord::Tasks::DatabaseTasks.create @configuration
      end

      def test_sends_output_to_stderr_when_other_errors
        @error.stubs(:errno).returns(42)

        $stderr.expects(:puts).at_least_once.returns(nil)

        ActiveRecord::Tasks::DatabaseTasks.create @configuration
      end

      private
        def assert_permissions_granted_for(db_user)
          db_name = @configuration['database']
          db_password = @configuration['password']
          @connection.expects(:execute).with("GRANT ALL PRIVILEGES ON #{db_name}.* TO '#{db_user}'@'localhost' IDENTIFIED BY '#{db_password}' WITH GRANT OPTION;")
        end
    end
  end

  class MySQLDBDropTest < ActiveRecord::TestCase
    def setup
      @connection    = stub(:drop_database => true)
      @configuration = {
        'adapter'  => 'mysql',
        'database' => 'my-app-db'
      }

      ActiveRecord::Base.stubs(:connection).returns(@connection)
      ActiveRecord::Base.stubs(:establish_connection).returns(true)
    end

    def test_establishes_connection_to_mysql_database
      ActiveRecord::Base.expects(:establish_connection).with @configuration

      ActiveRecord::Tasks::DatabaseTasks.drop @configuration
    end

    def test_drops_database
      @connection.expects(:drop_database).with('my-app-db')

      ActiveRecord::Tasks::DatabaseTasks.drop @configuration
    end
  end

  class MySQLPurgeTest < ActiveRecord::TestCase
    def setup
      @connection    = stub(:recreate_database => true)
      @configuration = {
        'adapter'  => 'mysql',
        'database' => 'test-db'
      }

      ActiveRecord::Base.stubs(:connection).returns(@connection)
      ActiveRecord::Base.stubs(:establish_connection).returns(true)
    end

    def test_establishes_connection_to_the_appropriate_database
      ActiveRecord::Base.expects(:establish_connection).with(@configuration)

      ActiveRecord::Tasks::DatabaseTasks.purge @configuration
    end

    def test_recreates_database_with_the_default_options
      @connection.expects(:recreate_database).
        with('test-db', charset: 'utf8', collation: 'utf8_unicode_ci')

      ActiveRecord::Tasks::DatabaseTasks.purge @configuration
    end

    def test_recreates_database_with_the_given_options
      @connection.expects(:recreate_database).
        with('test-db', charset: 'latin', collation: 'latin1_swedish_ci')

      ActiveRecord::Tasks::DatabaseTasks.purge @configuration.merge(
        'encoding' => 'latin', 'collation' => 'latin1_swedish_ci')
    end
  end

  class MysqlDBCharsetTest < ActiveRecord::TestCase
    def setup
      @connection    = stub(:create_database => true)
      @configuration = {
        'adapter'  => 'mysql',
        'database' => 'my-app-db'
      }

      ActiveRecord::Base.stubs(:connection).returns(@connection)
      ActiveRecord::Base.stubs(:establish_connection).returns(true)
    end

    def test_db_retrieves_charset
      @connection.expects(:charset)
      ActiveRecord::Tasks::DatabaseTasks.charset @configuration
    end
  end

  class MysqlDBCollationTest < ActiveRecord::TestCase
    def setup
      @connection    = stub(:create_database => true)
      @configuration = {
        'adapter'  => 'mysql',
        'database' => 'my-app-db'
      }

      ActiveRecord::Base.stubs(:connection).returns(@connection)
      ActiveRecord::Base.stubs(:establish_connection).returns(true)
    end

    def test_db_retrieves_collation
      @connection.expects(:collation)
      ActiveRecord::Tasks::DatabaseTasks.collation @configuration
    end
  end

  class MySQLStructureDumpTest < ActiveRecord::TestCase
    def setup
      @configuration = {
        'adapter'  => 'mysql',
        'database' => 'test-db'
      }
    end

    def test_structure_dump
      filename = "awesome-file.sql"
      Kernel.expects(:system).with("mysqldump", "--result-file", filename, "--no-data", "test-db").returns(true)

      ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename)
    end

    def test_warn_when_external_structure_dump_fails
      filename = "awesome-file.sql"
      Kernel.expects(:system).with("mysqldump", "--result-file", filename, "--no-data", "test-db").returns(false)

      # There doesn't seem to be a good way to get a handle on a Process::Status object without actually
      # creating a child process, hence this to populate $?
      system("not_a_real_program_#{SecureRandom.hex}")
      assert_raise(RuntimeError) {
        ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename)
      }
    end

    def test_warn_when_external_structure_dump_command_execution_fails
      filename = "awesome-file.sql"
      Kernel.expects(:system)
        .with("mysqldump", "--result-file", filename, "--no-data", "test-db")
        .returns(nil)

      assert_raise(RuntimeError) {
        ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename)
      }
    end

    def test_structure_dump_with_port_number
      filename = "awesome-file.sql"
      Kernel.expects(:system).with("mysqldump", "--port", "10000", "--result-file", filename, "--no-data", "test-db").returns(true)

      ActiveRecord::Tasks::DatabaseTasks.structure_dump(
        @configuration.merge('port' => 10000),
        filename)
    end
  end

  class MySQLStructureLoadTest < ActiveRecord::TestCase
    def setup
      @configuration = {
        'adapter'  => 'mysql',
        'database' => 'test-db'
      }
    end

    def test_structure_load
      filename = "awesome-file.sql"
      Kernel.expects(:system).with('mysql', '--execute', %{SET FOREIGN_KEY_CHECKS = 0; SOURCE #{filename}; SET FOREIGN_KEY_CHECKS = 1}, "--database", "test-db")
        .returns(true)

      ActiveRecord::Tasks::DatabaseTasks.structure_load(@configuration, filename)
    end
  end

end
end
