class PluginBuilder < Rails::PluginBuilder
  def test
    create_file "spec/spec_helper.rb"
    append_file "Rakefile", <<-EOF
# spec tasks in rakefile

task default: :spec
    EOF
  end

  def generate_test_dummy
    dummy_path("spec/dummy")
    super
  end

  def skip_test_unit?
    true
  end
end
