# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/command"

class Rails::DestroyTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  setup :build_app
  teardown :teardown_app

  def test_destroy_model_reports_missing_model_file
    command_output = rails("destroy", "model", "Adress", allow_failure: true)

    assert_match(/Could not find model 'Adress'/, command_output)
    assert_equal 1, $?.exitstatus
  end

  def test_destroy_model_still_removes_existing_model
    rails "generate", "model", "Book", "title:string"

    assert File.exist?("#{app_path}/app/models/book.rb")

    command_output = rails "destroy", "model", "Book"

    assert_match(/remove\s+app\/models\/book\.rb/, command_output)
    assert_not File.exist?("#{app_path}/app/models/book.rb")
  end
end
