# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/rails/application_record/application_record_generator"

class ApplicationRecordGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper

  def test_application_record_skeleton_is_created
    run_generator
    assert_file "app/models/application_record.rb" do |record|
      assert_match(/class ApplicationRecord < ActiveRecord::Base/, record)
      assert_match(/self\.abstract_class = true/, record)
    end
  end
end
