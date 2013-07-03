require 'generators/generators_test_helper'
require 'rails/generators/rails/task/task_generator'

class TaskGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  arguments %w(feeds foo bar)

  def test_task_is_created
    run_generator
    assert_file "lib/tasks/feeds.rake", /namespace :feeds/
  end

  def test_file_is_opened_in_editor
    generator %w(feeds foo bar), editor: 'vim'
    generator.expects(:run).once.with("vim \"lib/tasks/feeds.rake\"")
    quietly { generator.invoke_all }
  end
end
