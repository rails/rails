require "abstract_unit"

class ParamsWrapperForApiTest < ActionController::TestCase
  class UsersController < ActionController::API
    attr_accessor :last_parameters

    wrap_parameters :person, format: [:json]

    def test
      self.last_parameters = params.except(:controller, :action).to_unsafe_h
      head :ok
    end
  end

  class Person; end

  tests UsersController

  def test_specify_wrapper_name
    @request.env["CONTENT_TYPE"] = "application/json"
    post :test, params: { "username" => "sikachu" }

    expected = { "username" => "sikachu", "person" => { "username" => "sikachu" } }
    assert_equal expected, @controller.last_parameters
  end
end
