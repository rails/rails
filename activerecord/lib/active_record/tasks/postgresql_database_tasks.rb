class ActiveRecord::Tasks::PostgreSQLDatabaseTasks
  DEFAULT_ENCODING = ENV['CHARSET'] || 'utf8'

  delegate :connection, :establish_connection, :to => ActiveRecord::Base

  def initialize(configuration)
    @configuration = configuration
  end

  def create
    establish_connection configuration.merge(
      'database' => 'postgres',
      'schema_search_path' => 'public'
    )
    connection.create_database configuration['database'],
      configuration.merge('encoding' => encoding)
    establish_connection configuration
  end

  private

  attr_reader :configuration

  def encoding
    configuration['encoding'] || DEFAULT_ENCODING
  end
end
