# frozen_string_literal: true

require_relative "abstract_unit"

class EnvironmentInquirerTest < ActiveSupport::TestCase
  test "local predicate" do
    assert_predicate ActiveSupport::EnvironmentInquirer.new("development"), :local?
    assert_predicate ActiveSupport::EnvironmentInquirer.new("test"), :local?
    assert_not ActiveSupport::EnvironmentInquirer.new("production").local?
  end

  test "development predicate" do
    assert_predicate ActiveSupport::EnvironmentInquirer.new("development"), :development?
    assert_not ActiveSupport::EnvironmentInquirer.new("test").development?
    assert_not ActiveSupport::EnvironmentInquirer.new("production").development?
  end

  test "test predicate" do
    assert_predicate ActiveSupport::EnvironmentInquirer.new("test"), :test?
    assert_not ActiveSupport::EnvironmentInquirer.new("development").test?
    assert_not ActiveSupport::EnvironmentInquirer.new("production").test?
  end

  test "production predicate" do
    assert_predicate ActiveSupport::EnvironmentInquirer.new("production"), :production?
    assert_not ActiveSupport::EnvironmentInquirer.new("development").production?
    assert_not ActiveSupport::EnvironmentInquirer.new("test").production?
  end

  test "custom environment falls back to StringInquirer" do
    env = ActiveSupport::EnvironmentInquirer.new("staging")
    assert_predicate env, :staging?
    assert_not env.development?
    assert_not env.test?
    assert_not env.production?
  end

  test "local predicate returns false for non-local environments" do
    assert_not ActiveSupport::EnvironmentInquirer.new("staging").local?
  end

  test "prevent local from being used as an actual environment name" do
    assert_raises(ArgumentError) do
      ActiveSupport::EnvironmentInquirer.new("local")
    end
  end
end
