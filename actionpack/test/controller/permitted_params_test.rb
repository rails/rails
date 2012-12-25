require 'abstract_unit'

class PeopleController < ActionController::Base
  def create
    render text: params[:person].permitted? ? "permitted" : "forbidden"
  end

  def create_with_permit
    render text: params[:person].permit(:name).permitted? ? "permitted" : "forbidden"
  end
end

class ActionControllerPermittedParamsTest < ActionController::TestCase
  tests PeopleController

  test "parameters are forbidden" do
    post :create, { person: { name: "Mjallo!" } }
    assert_equal "forbidden", response.body
  end

  test "parameters can be permitted and are then not forbidden" do
    post :create_with_permit, { person: { name: "Mjallo!" } }
    assert_equal "permitted", response.body
  end
end
