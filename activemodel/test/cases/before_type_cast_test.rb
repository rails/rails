# frozen_string_literal: true

require "cases/helper"

class BeforeTypeCastTest < ActiveModel::TestCase
  class Developer
    include ActiveModel::Attributes

    attribute :name, :string
    attribute :salary, :integer
    attribute :active, :boolean
    alias_attribute :compensation, :salary

    def initialize(attributes = {})
      super()
      attributes.each { |name, value| public_send("#{name}=", value) }
    end
  end

  setup do
    @before_type_cast = { name: 1234, salary: "56789", active: "0" }
    @after_type_cast = { name: "1234", salary: 56789, active: false }
    @developer = Developer.new(@before_type_cast)
  end

  test "#read_attribute_before_type_cast" do
    assert_equal @before_type_cast[:salary], @developer.read_attribute_before_type_cast(:salary)
  end

  test "#read_attribute_before_type_cast with aliased attribute" do
    assert_equal @before_type_cast[:salary], @developer.read_attribute_before_type_cast(:compensation)
  end

  test "#read_attribute_for_database" do
    assert_equal @after_type_cast[:salary], @developer.read_attribute_for_database(:salary)
  end

  test "#read_attribute_for_database with aliased attribute" do
    assert_equal @after_type_cast[:salary], @developer.read_attribute_for_database(:compensation)
  end

  test "#attributes_before_type_cast" do
    assert_equal @before_type_cast.transform_keys(&:to_s), @developer.attributes_before_type_cast
  end

  test "#attributes_before_type_cast with missing attributes" do
    assert_equal @before_type_cast.to_h { |key, value| [key.to_s, nil] }, Developer.new.attributes_before_type_cast
  end

  test "#attributes_for_database" do
    assert_equal @after_type_cast.transform_keys(&:to_s), @developer.attributes_for_database
  end

  test "#*_before_type_cast" do
    assert_equal @before_type_cast[:salary], @developer.salary_before_type_cast
  end

  test "#*_before_type_cast with aliased attribute" do
    assert_equal @before_type_cast[:salary], @developer.compensation_before_type_cast
  end

  test "#*_for_database" do
    assert_equal @after_type_cast[:salary], @developer.salary_for_database
  end

  test "#*_for_database with aliased attribute" do
    assert_equal @after_type_cast[:salary], @developer.compensation_for_database
  end

  test "#*_came_from_user?" do
    assert_predicate @developer, :salary_came_from_user?
    assert_not_predicate Developer.new, :salary_came_from_user?
  end

  test "#*_came_from_user? with aliased attribute" do
    assert_predicate @developer, :compensation_came_from_user?
    assert_not_predicate Developer.new, :compensation_came_from_user?
  end
end
