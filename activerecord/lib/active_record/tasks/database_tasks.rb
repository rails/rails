class ActiveRecord::Tasks::DatabaseTasks
  TASKS_PATTERNS = {
    /mysql/      => ActiveRecord::Tasks::MySQLDatabaseTasks,
    /postgresql/ => ActiveRecord::Tasks::PostgreSQLDatabaseTasks,
    /sqlite/     => ActiveRecord::Tasks::SQLiteDatabaseTasks
  }
  LOCAL_HOSTS    = ['127.0.0.1', 'localhost']

  def self.create(*arguments)
    configuration = arguments.first
    class_for_adapter(configuration['adapter']).new(*arguments).create
  rescue Exception => error
    $stderr.puts error, *(error.backtrace)
    $stderr.puts "Couldn't create database for #{configuration.inspect}"
  end

  def self.create_all
    each_local_configuration { |configuration| create configuration }
  end

  def self.create_current(environment = Rails.env)
    each_current_configuration(environment) { |configuration|
      create configuration
    }
    ActiveRecord::Base.establish_connection environment
  end

  def self.drop(*arguments)
    configuration = arguments.first
    class_for_adapter(configuration['adapter']).new(*arguments).drop
  rescue Exception => error
    $stderr.puts error, *(error.backtrace)
    $stderr.puts "Couldn't drop #{configuration['database']}"
  end

  def self.drop_all
    each_local_configuration { |configuration| drop configuration }
  end

  def self.drop_current(environment = Rails.env)
    each_current_configuration(environment) { |configuration|
      drop configuration
    }
  end

  def self.purge(configuration)
    class_for_adapter(configuration['adapter']).new(configuration).purge
  end

  private

  def self.class_for_adapter(adapter)
    key = TASKS_PATTERNS.keys.detect { |pattern| adapter[pattern] }
    TASKS_PATTERNS[key]
  end

  def self.each_current_configuration(environment)
    environments = [environment]
    environments << 'test' if environment.development?

    configurations = ActiveRecord::Base.configurations.values_at(*environments)
    configurations.compact.each do |configuration|
      yield configuration unless configuration['database'].blank?
    end
  end

  def self.each_local_configuration
    ActiveRecord::Base.configurations.each_value do |configuration|
      next unless configuration['database']

      if local_database?(configuration)
        yield configuration
      else
        $stderr.puts "This task only modifies local databases. #{configuration['database']} is on a remote host."
      end
    end
  end

  def self.local_database?(configuration)
    configuration['host'].in?(LOCAL_HOSTS) || configuration['host'].blank?
  end
end
