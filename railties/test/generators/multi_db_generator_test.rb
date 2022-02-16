# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/active_record/multi_db/multi_db_generator"

class MultiDbGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  tests ActiveRecord::Generators::MultiDbGenerator

  def test_multi_db_skeleton_is_created
    run_generator
    assert_file "config/initializers/multi_db.rb" do |record|
      assert_match(/Multi-db Configuration/, record)
      assert_match(/config.active_record.database_resolver/, record)
      assert_match(/config.active_record.shard_resolver/, record)
    end
  end
end
