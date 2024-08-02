# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/command"
require "rails/commands/boot/boot_command"

class Rails::Command::BootTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  setup :build_app
  teardown :teardown_app

  test "boots the application" do
    test_file = "#{app_path}/tmp/test_file"

    app_file "config/initializers/write_test_file.rb", <<-RUBY
      File.write(#{test_file.inspect}, Rails.env)
    RUBY

    rails "boot"

    assert_equal "development", File.read(test_file)
  end

  test "optionally accepts an environment" do
    test_file = "#{app_path}/tmp/test_file"

    app_file "config/initializers/write_test_file.rb", <<-RUBY
      File.write(#{test_file.inspect}, Rails.env)
    RUBY

    rails "boot", "-e", "test"

    assert_equal "test", File.read(test_file)
  end
end
