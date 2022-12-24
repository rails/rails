# frozen_string_literal: true

require_relative "abstract_unit"

class EnvironmentInquirerTest < ActiveSupport::TestCase
  test "local predicate" do
    assert ActiveSupport::EnvironmentInquirer.new("development").local?
    assert ActiveSupport::EnvironmentInquirer.new("test").local?
    assert_not ActiveSupport::EnvironmentInquirer.new("production").local?
  end

  test "remote predicate" do
    assert ActiveSupport::EnvironmentInquirer.new("production").remote?
    assert ActiveSupport::EnvironmentInquirer.new("staging").remote?
    assert_not ActiveSupport::EnvironmentInquirer.new("development").remote?
    assert_not ActiveSupport::EnvironmentInquirer.new("test").remote?
  end

  test "prevent local from being used as an actual environment name" do
    assert_raises(ArgumentError) do
      ActiveSupport::EnvironmentInquirer.new("local")
    end
  end

  test "prevent remote from being used as an actual environment name" do
    assert_raises(ArgumentError) do
      ActiveSupport::EnvironmentInquirer.new("remote")
    end
  end
end
