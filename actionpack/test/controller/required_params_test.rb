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
end
