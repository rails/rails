require 'generators/generators_test_helper'
require 'rails/generators/rails/task/task_generator'

class TaskGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  arguments %w(feeds foo bar)

  def test_controller_skeleton_is_created
    run_generator
    assert_file "lib/tasks/feeds.rake", /namespace :feeds/
  end
end
