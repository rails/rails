# frozen_string_literal: true

module LoadSchemaHelper
  def load_schema
    # silence verbose schema loading
    original_stdout = $stdout
    $stdout = StringIO.new

    adapter_name = ActiveRecord::Base.lease_connection.adapter_name.downcase
    adapter_specific_schema_file = SCHEMA_ROOT + "/#{adapter_name}_specific_schema.rb"

    load SCHEMA_ROOT + "/schema.rb"

    if File.exist?(adapter_specific_schema_file)
      load adapter_specific_schema_file
    end

    ActiveRecord::FixtureSet.reset_cache
  ensure
    $stdout = original_stdout
  end
end
