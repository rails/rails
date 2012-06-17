class ActiveRecord::Tasks::DatabaseTasks
  TASKS_PATTERNS = {
    /mysql/      => ActiveRecord::Tasks::MySQLDatabaseTasks,
    /postgresql/ => ActiveRecord::Tasks::PostgreSQLDatabaseTasks,
    /sqlite/     => ActiveRecord::Tasks::SQLiteDatabaseTasks
  }

  def self.create(configuration)
    class_for_adapter(configuration['adapter']).new(configuration).create
  rescue Exception => error
    $stderr.puts error, *(error.backtrace)
    $stderr.puts "Couldn't create database for #{configuration.inspect}"
  end

  def self.drop(configuration)
    class_for_adapter(configuration['adapter']).new(configuration).drop
  rescue Exception => error
    $stderr.puts error, *(error.backtrace)
    $stderr.puts "Couldn't drop #{configuration['database']}"
  end

  def self.purge(configuration)
    class_for_adapter(configuration['adapter']).new(configuration).purge
  end

  def self.class_for_adapter(adapter)
    key = TASKS_PATTERNS.keys.detect { |key| adapter[key] }
    TASKS_PATTERNS[key]
  end
end
