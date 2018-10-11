# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/command"

class Rails::Command::InitializersTest < ActiveSupport::TestCase
  setup :build_app
  teardown :teardown_app

  test "`rails initializers` prints out defined initializers invoked by Rails" do
    initial_output = run_initializers_command
    initial_output_length = initial_output.split("\n").length

    assert_operator initial_output_length, :>, 0
    assert_not initial_output.include?("set_added_test_module")

    add_to_config <<-RUBY
      initializer(:set_added_test_module) { }
    RUBY

    final_output = run_initializers_command
    final_output_length = final_output.split("\n").length

    assert_equal 1, (final_output_length - initial_output_length)
    assert final_output.include?("set_added_test_module")
  end

  private
    def run_initializers_command
      rails "initializers"
    end
end
