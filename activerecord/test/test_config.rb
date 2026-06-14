# frozen_string_literal: true

require_relative "config"
require_relative "support/config"
require_relative "support/connection"

adapter_name = ARTest.config.dig("connections", ARTest.connection_name, "arunit", "adapter")

Megatest.config do |c|
  other_adapters = Dir["*", base: File.expand_path("../cases/adapters/", __FILE__)]
  other_adapters.delete(adapter_name)
  case adapter_name
  when "trilogy", "mysql2"
    other_adapters.delete("abstract_mysql_adapter")
  end

  adapter_loaders = other_adapters.map do |adapter|
    Megatest::Selector::Loader.new(c, File.expand_path("../cases/adapters/#{adapter}", __FILE__))
  end

  c.selectors.loaders.concat(adapter_loaders.map { |l| Megatest::Selector::NegativeLoader.new(l) })

  # FIXME: we got tests without any assertions
  c.minitest_compatibility = true

  if ARTest.connection_name == "sqlite3_mem"
    c.jobs_count = :number_of_processors

    c.job_setup do |_, index|
      ActiveRecord::TestCase.load_schema
    end
  else
    # TODO: support parallel testing for other dbs. That means multiple databases etc
    c.jobs_count = 1
  end
end
