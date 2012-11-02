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

  def test_glob_constraint
    get "/dummy"
    assert_equal "301", @response.code
    assert_equal "/not_cars", @response.header['Location'].match('/[^/]+$')[0]
  end

  def test_glob_constraint_skip_route
    get "/cars"
    assert_equal "200", @response.code
  end
end
