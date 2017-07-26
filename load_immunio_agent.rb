puts '=' * 80
puts 'Requiring load_immunio_agent'
puts '=' * 80

if ENV.has_key? 'IMMUNIO_AGENT_DIR'
  puts '=' * 80
  puts 'Loading agent'
  puts '=' * 80

  # Immunio assumes rails is already loaded.
  require 'rails/all'

  # Workaround adapters only loaded depending on the database adapter.
  require 'active_record/connection_adapters/mysql2_adapter'
  require 'active_record/connection_adapters/postgresql_adapter'
  require 'active_record/connection_adapters/sqlite3_adapter'

  # Activate the agent.
  require 'immunio'

  if Immunio.agent.agent_enabled
    # Workaround active_record only activated after active_record.initialize_database.
    Immunio::Plugin.load 'ActionRecord',
                         feature: 'sqli',
                         hooks: %w( sql_execute ) do |plugin|
      immunio_dir = ENV.fetch "IMMUNIO_AGENT_DIR"
      require_relative "#{immunio_dir}/lib/immunio/plugins/active_record"
      plugin.loaded! ActiveRecord::VERSION::STRING
    end

    # Workaround request required for running hooks.
    require 'immunio/request'

    Immunio.agent.new_request(
      Immunio::Request.new(
      {
        "id" => 123.0,
        "test" => [
          { "plugin" => "test" },
          { "plugin" => "indeed" },
        ]
      }))

    puts '=' * 80
    puts 'Agent loaded!'
    puts '=' * 80
  end
end
