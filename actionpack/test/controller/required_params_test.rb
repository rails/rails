require 'abstract_unit'

class BooksController < ActionController::Base
  def create
    params.require(:book).require(:name)
    head :ok
  end
end

class ActionControllerRequiredParamsTest < ActionController::TestCase
  tests BooksController

  test "missing required parameters will raise exception" do
    assert_raise ActionController::ParameterMissing do
      post :create, { magazine: { name: "Mjallo!" } }
    end

    assert_raise ActionController::ParameterMissing do
      post :create, { book: { title: "Mjallo!" } }
    end
  end

  test "required parameters that are present will not raise" do
    post :create, { book: { name: "Mjallo!" } }
    assert_response :ok
  end

  test "required parameters with false value will not raise" do
    post :create, { book: { name: false } }
    assert_response :ok
  end
end

class ParametersRequireTest < ActiveSupport::TestCase

  test "required parameters should accept and return false value" do
    assert_equal(false, ActionController::Parameters.new(person: false).require(:person))
  end

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
end
