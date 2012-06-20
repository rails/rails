require 'cases/helper'

module ActiveRecord
  class DatabaseTasksCreateTest < ActiveRecord::TestCase
    def setup
      @mysql_tasks, @postgresql_tasks, @sqlite_tasks = stub, stub, stub

      ActiveRecord::Tasks::MySQLDatabaseTasks.stubs(:new).returns @mysql_tasks
      ActiveRecord::Tasks::PostgreSQLDatabaseTasks.stubs(:new).
        returns @postgresql_tasks
      ActiveRecord::Tasks::SQLiteDatabaseTasks.stubs(:new).returns @sqlite_tasks
    end

    def test_mysql_create
      @mysql_tasks.expects(:create)

      ActiveRecord::Tasks::DatabaseTasks.create 'adapter' => 'mysql'
    end

    def test_mysql2_create
      @mysql_tasks.expects(:create)

      ActiveRecord::Tasks::DatabaseTasks.create 'adapter' => 'mysql2'
    end

    def test_postgresql_create
      @postgresql_tasks.expects(:create)

      ActiveRecord::Tasks::DatabaseTasks.create 'adapter' => 'postgresql'
    end

    def test_sqlite_create
      @sqlite_tasks.expects(:create)

      ActiveRecord::Tasks::DatabaseTasks.create 'adapter' => 'sqlite3'
    end
  end

  class DatabaseTasksCreateAllTest < ActiveRecord::TestCase
    def setup
      @configurations = {'development' => {'database' => 'my-db'}}

      ActiveRecord::Base.stubs(:configurations).returns(@configurations)
    end

    def test_ignores_configurations_without_databases
      @configurations['development'].merge!('database' => nil)

      ActiveRecord::Tasks::DatabaseTasks.expects(:create).never

      ActiveRecord::Tasks::DatabaseTasks.create_all
    end

    def test_ignores_remote_databases
      @configurations['development'].merge!('host' => 'my.server.tld')
      $stderr.stubs(:puts).returns(nil)

      ActiveRecord::Tasks::DatabaseTasks.expects(:create).never

      ActiveRecord::Tasks::DatabaseTasks.create_all
    end

    def test_warning_for_remote_databases
      @configurations['development'].merge!('host' => 'my.server.tld')

      $stderr.expects(:puts).with('This task only modifies local databases. my-db is on a remote host.')

      ActiveRecord::Tasks::DatabaseTasks.create_all
    end

    def test_creates_configurations_with_local_ip
      @configurations['development'].merge!('host' => '127.0.0.1')

      ActiveRecord::Tasks::DatabaseTasks.expects(:create)

      ActiveRecord::Tasks::DatabaseTasks.create_all
    end

    def test_creates_configurations_with_local_host
      @configurations['development'].merge!('host' => 'localhost')

      ActiveRecord::Tasks::DatabaseTasks.expects(:create)

      ActiveRecord::Tasks::DatabaseTasks.create_all
    end

    def test_creates_configurations_with_blank_hosts
      @configurations['development'].merge!('host' => nil)

      ActiveRecord::Tasks::DatabaseTasks.expects(:create)

      ActiveRecord::Tasks::DatabaseTasks.create_all
    end
  end

  class DatabaseTasksCreateCurrentTest < ActiveRecord::TestCase
    def setup
      @configurations = {
        'development' => {'database' => 'dev-db'},
        'test'        => {'database' => 'test-db'},
        'production'  => {'database' => 'prod-db'}
      }

      ActiveRecord::Base.stubs(:configurations).returns(@configurations)
      ActiveRecord::Base.stubs(:establish_connection).returns(true)
    end

    def test_creates_current_environment_database
      ActiveRecord::Tasks::DatabaseTasks.expects(:create).
        with('database' => 'prod-db')

      ActiveRecord::Tasks::DatabaseTasks.create_current(
        ActiveSupport::StringInquirer.new('production')
      )
    end

    def test_creates_test_database_when_environment_is_database
      ActiveRecord::Tasks::DatabaseTasks.expects(:create).
        with('database' => 'dev-db')
      ActiveRecord::Tasks::DatabaseTasks.expects(:create).
        with('database' => 'test-db')

      ActiveRecord::Tasks::DatabaseTasks.create_current(
        ActiveSupport::StringInquirer.new('development')
      )
    end

    def test_establishes_connection_for_the_given_environment
      ActiveRecord::Tasks::DatabaseTasks.stubs(:create).returns true

      ActiveRecord::Base.expects(:establish_connection).with('development')

      ActiveRecord::Tasks::DatabaseTasks.create_current(
        ActiveSupport::StringInquirer.new('development')
      )
    end
  end

  class DatabaseTasksDropTest < ActiveRecord::TestCase
    def setup
      @mysql_tasks, @postgresql_tasks, @sqlite_tasks = stub, stub, stub

      ActiveRecord::Tasks::MySQLDatabaseTasks.stubs(:new).returns @mysql_tasks
      ActiveRecord::Tasks::PostgreSQLDatabaseTasks.stubs(:new).
        returns @postgresql_tasks
      ActiveRecord::Tasks::SQLiteDatabaseTasks.stubs(:new).returns @sqlite_tasks
    end

    def test_mysql_create
      @mysql_tasks.expects(:drop)

      ActiveRecord::Tasks::DatabaseTasks.drop 'adapter' => 'mysql'
    end

    def test_mysql2_create
      @mysql_tasks.expects(:drop)

      ActiveRecord::Tasks::DatabaseTasks.drop 'adapter' => 'mysql2'
    end

    def test_postgresql_create
      @postgresql_tasks.expects(:drop)

      ActiveRecord::Tasks::DatabaseTasks.drop 'adapter' => 'postgresql'
    end

    def test_sqlite_create
      @sqlite_tasks.expects(:drop)

      ActiveRecord::Tasks::DatabaseTasks.drop 'adapter' => 'sqlite3'
    end
  end

  class DatabaseTasksDropAllTest < ActiveRecord::TestCase
    def setup
      @configurations = {:development => {'database' => 'my-db'}}

      ActiveRecord::Base.stubs(:configurations).returns(@configurations)
    end

    def test_ignores_configurations_without_databases
      @configurations[:development].merge!('database' => nil)

      ActiveRecord::Tasks::DatabaseTasks.expects(:drop).never

      ActiveRecord::Tasks::DatabaseTasks.drop_all
    end

    def test_ignores_remote_databases
      @configurations[:development].merge!('host' => 'my.server.tld')
      $stderr.stubs(:puts).returns(nil)

      ActiveRecord::Tasks::DatabaseTasks.expects(:drop).never

      ActiveRecord::Tasks::DatabaseTasks.drop_all
    end

    def test_warning_for_remote_databases
      @configurations[:development].merge!('host' => 'my.server.tld')

      $stderr.expects(:puts).with('This task only modifies local databases. my-db is on a remote host.')

      ActiveRecord::Tasks::DatabaseTasks.drop_all
    end

    def test_creates_configurations_with_local_ip
      @configurations[:development].merge!('host' => '127.0.0.1')

      ActiveRecord::Tasks::DatabaseTasks.expects(:drop)

      ActiveRecord::Tasks::DatabaseTasks.drop_all
    end

    def test_creates_configurations_with_local_host
      @configurations[:development].merge!('host' => 'localhost')

      ActiveRecord::Tasks::DatabaseTasks.expects(:drop)

      ActiveRecord::Tasks::DatabaseTasks.drop_all
    end

    def test_creates_configurations_with_blank_hosts
      @configurations[:development].merge!('host' => nil)

      ActiveRecord::Tasks::DatabaseTasks.expects(:drop)

      ActiveRecord::Tasks::DatabaseTasks.drop_all
    end
  end

  class DatabaseTasksDropCurrentTest < ActiveRecord::TestCase
    def setup
      @configurations = {
        'development' => {'database' => 'dev-db'},
        'test'        => {'database' => 'test-db'},
        'production'  => {'database' => 'prod-db'}
      }

      ActiveRecord::Base.stubs(:configurations).returns(@configurations)
    end

    def test_creates_current_environment_database
      ActiveRecord::Tasks::DatabaseTasks.expects(:drop).
        with('database' => 'prod-db')

      ActiveRecord::Tasks::DatabaseTasks.drop_current(
        ActiveSupport::StringInquirer.new('production')
      )
    end

    def test_creates_test_database_when_environment_is_database
      ActiveRecord::Tasks::DatabaseTasks.expects(:drop).
        with('database' => 'dev-db')
      ActiveRecord::Tasks::DatabaseTasks.expects(:drop).
        with('database' => 'test-db')

      ActiveRecord::Tasks::DatabaseTasks.drop_current(
        ActiveSupport::StringInquirer.new('development')
      )
    end
  end

  class DatabaseTasksPurgeTest < ActiveRecord::TestCase
    def setup
      @mysql_tasks, @postgresql_tasks, @sqlite_tasks = stub, stub, stub

      ActiveRecord::Tasks::MySQLDatabaseTasks.stubs(:new).returns @mysql_tasks
      ActiveRecord::Tasks::PostgreSQLDatabaseTasks.stubs(:new).
        returns @postgresql_tasks
      ActiveRecord::Tasks::SQLiteDatabaseTasks.stubs(:new).returns @sqlite_tasks
    end

    def test_mysql_create
      @mysql_tasks.expects(:purge)

      ActiveRecord::Tasks::DatabaseTasks.purge 'adapter' => 'mysql'
    end

    def test_mysql2_create
      @mysql_tasks.expects(:purge)

      ActiveRecord::Tasks::DatabaseTasks.purge 'adapter' => 'mysql2'
    end

    def test_postgresql_create
      @postgresql_tasks.expects(:purge)

      ActiveRecord::Tasks::DatabaseTasks.purge 'adapter' => 'postgresql'
    end

    def test_sqlite_create
      @sqlite_tasks.expects(:purge)

      ActiveRecord::Tasks::DatabaseTasks.purge 'adapter' => 'sqlite3'
    end
  end

  class DatabaseTasksCharsetTest < ActiveRecord::TestCase
    def setup
      @mysql_tasks, @postgresql_tasks, @sqlite_tasks = stub, stub, stub
      ActiveRecord::Tasks::MySQLDatabaseTasks.stubs(:new).returns @mysql_tasks
      ActiveRecord::Tasks::PostgreSQLDatabaseTasks.stubs(:new).
        returns @postgresql_tasks
      ActiveRecord::Tasks::SQLiteDatabaseTasks.stubs(:new).returns @sqlite_tasks
    end
 
    def test_mysql_charset
      @mysql_tasks.expects(:charset)

      ActiveRecord::Tasks::DatabaseTasks.charset 'adapter' => 'mysql'
    end

    def test_mysql2_charset
      @mysql_tasks.expects(:charset)

      ActiveRecord::Tasks::DatabaseTasks.charset 'adapter' => 'mysql2'
    end

    def test_postgresql_charset
      @postgresql_tasks.expects(:charset)

      ActiveRecord::Tasks::DatabaseTasks.charset 'adapter' => 'postgresql'
    end

    def test_sqlite_charset
      @sqlite_tasks.expects(:charset)

      ActiveRecord::Tasks::DatabaseTasks.charset 'adapter' => 'sqlite3'
    end
  end

  class DatabaseTasksStructureDumpTest < ActiveRecord::TestCase
    def setup
      @mysql_tasks, @postgresql_tasks, @sqlite_tasks = stub, stub, stub
      ActiveRecord::Tasks::MySQLDatabaseTasks.stubs(:new).returns @mysql_tasks
      ActiveRecord::Tasks::PostgreSQLDatabaseTasks.stubs(:new).
        returns @postgresql_tasks
      ActiveRecord::Tasks::SQLiteDatabaseTasks.stubs(:new).returns @sqlite_tasks
    end

    def test_mysql_structure_dump
      @mysql_tasks.expects(:structure_dump).with("awesome-file.sql")

      ActiveRecord::Tasks::DatabaseTasks.structure_dump({'adapter' => 'mysql'}, "awesome-file.sql")
    end

    def test_mysql2_structure_dump
      @mysql_tasks.expects(:structure_dump).with("awesome-file.sql")

      ActiveRecord::Tasks::DatabaseTasks.structure_dump({'adapter' => 'mysql2'}, "awesome-file.sql")
    end

    def test_postgresql_structure_dump
      @postgresql_tasks.expects(:structure_dump).with("awesome-file.sql")

      ActiveRecord::Tasks::DatabaseTasks.structure_dump({'adapter' => 'postgresql'}, "awesome-file.sql")
    end

    def test_sqlite_structure_dump
      @sqlite_tasks.expects(:structure_dump).with("awesome-file.sql")

      ActiveRecord::Tasks::DatabaseTasks.structure_dump({'adapter' => 'sqlite3'}, "awesome-file.sql")
    end
  end
end
