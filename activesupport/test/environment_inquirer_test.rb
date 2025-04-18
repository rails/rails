# frozen_string_literal: true

require_relative "abstract_unit"

class EnvironmentInquirerTest < ActiveSupport::TestCase
  test "local predicate" do
    assert_predicate ActiveSupport::EnvironmentInquirer.new("development"), :local?
    assert_predicate ActiveSupport::EnvironmentInquirer.new("test"), :local?
    assert_not ActiveSupport::EnvironmentInquirer.new("production").local?
  end

  test "prevent local from being used as an actual environment name" do
    assert_raises(ArgumentError) do
      ActiveSupport::EnvironmentInquirer.new("local")
    end
  end
end
