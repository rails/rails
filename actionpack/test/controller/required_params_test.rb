# frozen_string_literal: true

require "abstract_unit"

class BooksController < ActionController::Base
  def create
    params.require(:book).require_scalar(:name)
    head :ok
  end
end

class ActionControllerRequiredParamsTest < ActionController::TestCase
  tests BooksController

  test "missing required parameters will raise exception" do
    assert_raise ActionController::ParameterMissing do
      post :create, params: { magazine: { name: "Mjallo!" } }
    end

    assert_raise ActionController::ParameterMissing do
      post :create, params: { book: { title: "Mjallo!" } }
    end
  end

  test "exceptions have suggestions for fix" do
    error = assert_raise ActionController::ParameterMissing do
      post :create, params: { boko: { name: "Mjallo!" } }
    end
    assert_match "Did you mean?", error.message

    error = assert_raise ActionController::ParameterMissing do
      post :create, params: { book: { naem: "Mjallo!" } }
    end
    assert_match "Did you mean?", error.message
  end

  test "required parameters that are present will not raise" do
    post :create, params: { book: { name: "Mjallo!" } }
    assert_response :ok
  end

  test "required parameters with false value will not raise" do
    post :create, params: { book: { name: false } }
    assert_response :ok
  end
end

class ParametersRequireTest < ActiveSupport::TestCase
  test "required parameters must not be nil" do
    assert_raises(ActionController::ParameterMissing) do
      ActionController::Parameters.new(person: nil).require(:person)
    end
  end

  test "required parameters must not be empty" do
    assert_raises(ActionController::ParameterMissing) do
      ActionController::Parameters.new(person: {}).require(:person)
    end
  end

  test "require array when all required params are present" do
    safe_params = ActionController::Parameters.new(person: { first_name: "Gaurish" }, profile: { title: "Mjallo" })
      .require([:person, :profile])

    assert_kind_of Array, safe_params
    assert_equal "Gaurish", safe_params.first.require_scalar(:first_name)
    assert_equal "Mjallo", safe_params.last.require_scalar(:title)
  end

  test "require array when a required param is missing" do
    assert_raises(ActionController::ParameterMissing) do
      ActionController::Parameters.new(person: { first_name: "Gaurish" })
        .require([:person, :profile])
    end
  end

  test "require_scalar should accept and return scalar values" do
    params = ActionController::Parameters.new(name: "Gaurish")
    assert_equal("Gaurish", params.require_scalar(:name))
  end

  test "require_scalar ignores other keys" do
    params = ActionController::Parameters.new(name: "Gaurish", age: 22)
    assert_equal("Gaurish", params.require_scalar(:name))
  end

  test "require_scalar should accept and return false value" do
    params = ActionController::Parameters.new(enabled: false)
    assert_equal(false, params.require_scalar(:enabled))
  end

  test "required scalar must not be nil" do
    assert_raises(ActionController::ParameterMissing) do
      ActionController::Parameters.new(first_name: nil).require_scalar(:first_name)
    end
  end

  test "required scalar must not be a hash" do
    assert_raises(ActionController::ParameterMissing) do
      ActionController::Parameters.new(name: { first_name: "Gaurish" }).require_scalar(:name)
    end
  end

  test "required scalar must not be an array" do
    assert_raises(ActionController::ParameterMissing) do
      ActionController::Parameters.new(name: ["Gaurish", "Sharma"]).require_scalar(:name)
    end
  end

  test "required scalar must not be an unpermitted scalar value" do
    assert_raises(ActionController::ParameterMissing) do
      ActionController::Parameters.new(name: Object.new).require_scalar(:name)
    end
  end

  test "require_scalar with array when all required scalar are present" do
    safe_params = ActionController::Parameters.new(first_name: "Gaurish", title: "Mjallo", city: "Barcelona")
      .require_scalar([:first_name, :title])

    assert_kind_of Array, safe_params
    assert_equal ["Gaurish", "Mjallo"], safe_params
  end

  test "require_scalar with array when a required scalar is missing" do
    assert_raises(ActionController::ParameterMissing) do
      ActionController::Parameters.new(first_name: "Gaurish", title: nil)
        .require_scalar([:first_name, :title])
    end
  end

  test "value params" do
    params = ActionController::Parameters.new(foo: "bar", dog: "cinco")
    assert_equal ["bar", "cinco"], params.values
    assert params.has_value?("cinco")
    assert params.value?("cinco")
  end

  test "to_param works like in a Hash" do
    params = ActionController::Parameters.new(nested: { key: "value" }).permit!
    assert_equal({ nested: { key: "value" } }.to_param, params.to_param)

    params = { root: ActionController::Parameters.new(nested: { key: "value" }).permit! }
    assert_equal({ root: { nested: { key: "value" } } }.to_param, params.to_param)

    assert_raise(ActionController::UnfilteredParameters) do
      ActionController::Parameters.new(nested: { key: "value" }).to_param
    end
  end

  test "to_query works like in a Hash" do
    params = ActionController::Parameters.new(nested: { key: "value" }).permit!
    assert_equal({ nested: { key: "value" } }.to_query, params.to_query)

    params = { root: ActionController::Parameters.new(nested: { key: "value" }).permit! }
    assert_equal({ root: { nested: { key: "value" } } }.to_query, params.to_query)

    assert_raise(ActionController::UnfilteredParameters) do
      ActionController::Parameters.new(nested: { key: "value" }).to_query
    end
  end
end
