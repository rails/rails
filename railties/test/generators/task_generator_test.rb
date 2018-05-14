# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/rails/task/task_generator"

class TaskGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  arguments %w(feeds foo bar)

  def test_task_is_created
    run_generator
    assert_file "lib/tasks/feeds.rake" do |content|
      assert_match(/namespace :feeds/, content)
      assert_match(/task foo:/, content)
      assert_match(/task bar:/, content)
    end
  end

  def test_task_on_revoke
    task_path = "lib/tasks/feeds.rake"
    run_generator
    assert_file task_path
    run_generator ["feeds"], behavior: :revoke
    assert_no_file task_path
  end
end
