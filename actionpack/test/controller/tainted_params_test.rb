require 'abstract_unit'

class PeopleController < ActionController::Base
  def create
    render text: params[:person].permitted? ? "untainted" : "tainted"
  end

  def create_with_permit
    render text: params[:person].permit(:name).permitted? ? "untainted" : "tainted"
  end
end

class ActionControllerTaintedParamsTest < ActionController::TestCase
  tests PeopleController

  test "parameters are tainted" do
    post :create, { person: { name: "Mjallo!" } }
    assert_equal "tainted", response.body
  end

  test "parameters can be permitted and are then not tainted" do
    post :create_with_permit, { person: { name: "Mjallo!" } }
    assert_equal "untainted", response.body
  end
end
