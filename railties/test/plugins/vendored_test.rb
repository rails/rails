require "isolation/abstract_unit"

module ApplicationTests
  class PluginTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
    end

    test "generates the plugin" do
      script "generate plugin my_plugin"
      File.open("#{app_path}/vendor/plugins/my_plugin/init.rb", 'w') do |f|
        f.puts "OMG = 'hello'"
      end
      require "#{app_path}/config/environment"
    end
  end
end