class PluginBuilder < Rails::PluginBuilder
  def test
    create_file "spec/spec_helper.rb"
  end

  def test_path
    "spec"
  end

  def rakefile_test_tasks
    "# spec tasks in rakefile"
  end
end
