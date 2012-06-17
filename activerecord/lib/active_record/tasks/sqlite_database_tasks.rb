class ActiveRecord::Tasks::SQLiteDatabaseTasks
  delegate :connection, :establish_connection, :to => ActiveRecord::Base

  def initialize(configuration)
    @configuration = configuration
  end

  def create
    if File.exist? configuration['database']
      $stderr.puts "#{configuration['database']} already exists"
      return
    end

    establish_connection configuration
    connection
  end

  private

  attr_reader :configuration
end
