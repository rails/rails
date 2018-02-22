# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/rails/concern/concern_generator"

class ConcernGeneratorTest < Rails::Generator::TestCase
  include GeneratorsTestHelper

  def test_concern_skeleton_is_created
    run_generator ["taggable"]
    assert_file "app/models/concerns/taggable.rb" do |concern|
      assert_match(/module Taggable/, concern)
    end
  end

  def test_concern_namespace
    run_generator ["admin/taggable"]
    assert_file "app/models/concerns/admin/taggable.rb" do |concern|
      assert_match(/module Admin::Taggable < ApplicationJob/)
    end
  end

  def test_check_class_collision
    content = capture(:stderr) { run_generator ["concern"] }
    assert_match(/The name 'Concern' is either already used in your application or reserved/, content)
  end
end
