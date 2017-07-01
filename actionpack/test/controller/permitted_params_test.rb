require "abstract_unit"

class PeopleController < ActionController::Base
  def create
    render plain: params[:person].permitted? ? "permitted" : "forbidden"
  end

  def create_with_permit
    render plain: params[:person].permit(:name).permitted? ? "permitted" : "forbidden"
  end
end

class ActionControllerPermittedParamsTest < ActionController::TestCase
  tests PeopleController

  test "parameters are forbidden" do
    post :create, params: { person: { name: "Mjallo!" } }
    assert_equal "forbidden", response.body
  end

  test "parameters can be permitted and are then not forbidden" do
    post :create_with_permit, params: { person: { name: "Mjallo!" } }
    assert_equal "permitted", response.body
  end
end
