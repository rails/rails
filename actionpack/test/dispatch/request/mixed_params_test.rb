require 'abstract_unit'

class MixedParamsTest < ActionDispatch::IntegrationTest
  class TestController < ActionController::Base
    class << self
      attr_accessor :last_params
    end

    def parse
      self.class.last_params = params.reject { |key| key == 'action'}
      head :ok
    end
  end

  def teardown
    TestController.last_params = nil
  end

  test "mixed url_encoded and query string" do
    with_test_routing do
      actual = { "user" => { "name" => "vladson" }, "username" => "vb" }
      expected = { "user" => { "name" => "vladson", 'role' => 'dev' }, "username" => "vb", 'time' => 'adventure_time' }
      post '/parse', actual, "QUERY_STRING" => "user[role]=dev&time=adventure_time"
      assert_equal expected, TestController.last_params
    end
  end

  private

  def with_test_routing
    with_routing do |set|
      set.draw do
        post ':action', to: ::MixedParamsTest::TestController
      end
      yield
    end
  end

end