require 'generators/generators_test_helper'
require 'rails/generators/rails/task/task_generator'

class TaskGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  arguments %w(feeds foo bar)

  def test_creating_rake_task_by_default
    run_generator
    assert_file "lib/tasks/feeds.rake", /namespace :feeds/
  end
  
  def test_creating_thor_task
    run_generator ['feeds', 'foo', 'bar', '-t', 'thor']
    assert_file "lib/tasks/feeds.thor", /class Feeds < Thor/
  end
end
