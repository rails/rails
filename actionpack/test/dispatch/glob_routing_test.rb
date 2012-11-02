require 'abstract_unit'


class TestGlobRoutingMapper < ActionDispatch::IntegrationTest
  stub_controllers do |routes|
    Routes = routes
    Routes.draw do
      get "/*id" => redirect("/not_cars"), :constraints => {id: /dummy/}
      resource :cars
    end
  end

  include Routes.url_helpers
  def app; Routes end

  def test_glob_constraints
    get "/cars"
    assert_equal "200", @response.code
  end
end
