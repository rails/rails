require "abstract_unit"

class Rails::Engine::CommandsTasksTest < ActiveSupport::TestCase
  def setup
    @destination_root = Dir.mktmpdir("bukkits")
    Dir.chdir(@destination_root) { `bundle exec rails plugin new bukkits --mountable` }
  end

  def teardown
    FileUtils.rm_rf(@destination_root)
  end

  def test_help_command_work_inside_engine
    output = capture(:stderr) do
      Dir.chdir(plugin_path) { `bin/rails --help` }
    end
    assert_no_match "NameError", output
  end

  private
    def plugin_path
      "#{@destination_root}/bukkits"
    end
end
