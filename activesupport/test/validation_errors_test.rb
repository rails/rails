# frozen_string_literal: true

require_relative "abstract_unit"
require "active_model"

class ValidationErrorsTest < ActiveSupport::TestCase
  def setup
    @active_model = Class.new do
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :name, :string
      attribute :last_name, :string
      validates :name, :last_name, presence: true
      validate :name_doesnt_contain_numbers

      private
        def name_doesnt_contain_numbers
          unless name.nil? || name.scan(/\d/).empty?
            errors.add(:name, "shouldn't contain numbers")
          end
        end
    end.new
  end

  test "#assert_no_error_on asserts active model does not have an error on a field" do
    @active_model.name = "name"
    @active_model.validate

    assert_no_error_on @active_model, :name, :blank
  end

  test "#assert_no_error_on raises ArgumentError with an object that doesn't respond to errors" do
    error = assert_raises(ArgumentError) do
        assert_no_error_on Object.new, :name, :blank, Object.new
      end

    assert_includes error.message, "does not respond to #errors"
  end

  test "#assert_no_error_on raises a Minitest::Assertion when validation fails" do
    @active_model.validate
    error = assert_raises(Minitest::Assertion) do
      assert_no_error_on @active_model, :name, :blank
    end
    assert_includes error.message, "Expected name to not be blank"
  end

  test "#assert_error_on asserts active model has an error on name field" do
    @active_model.validate
    assert_error_on @active_model, :name, :blank
  end

  test "#assert_error_on asserts active model has an error on a field with a string" do
    error_message = "must start with H"
    @active_model.errors.add(:name, error_message)

    assert_error_on @active_model, :name, error_message
  end

  test "#assert_error_on raises ArgumentError on an object that doesn't respond to errors" do
    error = assert_raises(ArgumentError) do
      assert_error_on :name, :blank, Object.new
    end

    assert_includes error.message, "does not respond to #errors"
  end

  test "#assert_error_on raises a Minitest::Assertion when validation fails" do
    @active_model.name = "h"
    @active_model.validate
    error = assert_raises(Minitest::Assertion) do
      assert_error_on @active_model, :name, :blank
    end
    assert_includes error.message, "Expected error blank on name"
  end
end
