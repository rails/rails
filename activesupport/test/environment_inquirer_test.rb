# frozen_string_literal: true

require_relative "abstract_unit"

class EnvironmentInquirerTest < ActiveSupport::TestCase
  test "local predicate" do
    assert ActiveSupport::EnvironmentInquirer.new("development").local?
    assert ActiveSupport::EnvironmentInquirer.new("test").local?
    assert_not ActiveSupport::EnvironmentInquirer.new("production").local?
  end
end
