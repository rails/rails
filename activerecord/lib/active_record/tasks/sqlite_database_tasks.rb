class ActiveRecord::Tasks::SQLiteDatabaseTasks
  def initialize(configuration)
    @configuration = configuration
  end

  def create
    if File.exist?(configuration['database'])
      $stderr.puts "#{configuration['database']} already exists"
      return
    end

    ActiveRecord::Base.establish_connection(configuration)
    ActiveRecord::Base.connection
  end

  private

  attr_reader :configuration
end
