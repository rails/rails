# frozen_string_literal: true

require "abstract_unit"
require "plugin_helpers"

class Rails::Engine::TestTest < ActiveSupport::TestCase
  include PluginHelpers

  setup do
    @destination_root = Dir.mktmpdir("bukkits")
    generate_plugin("#{@destination_root}/bukkits", "--mountable")
  end

  teardown do
    FileUtils.rm_rf(@destination_root)
  end

  test "automatically synchronize test schema" do
    in_plugin_context(plugin_path) do
      # In order to confirm that migration files are loaded, generate multiple migration files.
      `bin/rails generate model user name:string;
       bin/rails generate model todo name:string;
       RAILS_ENV=development bin/rails db:migrate`

      output = `bin/rails test test/models/bukkits/user_test.rb`
      assert_includes(output, "0 runs, 0 assertions, 0 failures, 0 errors, 0 skips")
    end
  end

  private
    def plugin_path
      "#{@destination_root}/bukkits"
    end
end
