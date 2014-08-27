require 'abstract_unit'

class PeopleController < ActionController::Base
  def create
    render text: params[:person].permitted? ? "permitted" : "forbidden"
  end

  def create_with_permit
    render text: params[:person].permit(:name).permitted? ? "permitted" : "forbidden"
  end
end

class VilliansController < ActionController::Base

  whitelist_parameters create: {villian: [:name]}

  def create
    render text: create_params.permitted? ? "permitted" : "forbidden"
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

class ActionControllerWhitelistedParamsTest < ActionController::TestCase

  tests VilliansController

  test "parameters are permitted using #whitelist_params" do
    post :create, {villian: {name: "Joker"}}
    assert_equal "permitted", response.body
  end

end
