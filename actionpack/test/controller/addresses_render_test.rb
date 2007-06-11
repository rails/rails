require File.dirname(__FILE__) + '/../abstract_unit'

class Address

  def Address.count(conditions = nil, join = nil)
    nil
  end

  def Address.find_all(arg1, arg2, arg3, arg4)
    []
  end

  def self.find(*args)
    []
  end
end

class AddressesTestController < ActionController::Base
  scaffold :address

  def self.controller_name; "addresses"; end
  def self.controller_path; "addresses"; end
end

AddressesTestController.template_root = File.dirname(__FILE__) + "/../fixtures/"

class AddressesTest < Test::Unit::TestCase
  def setup
    @controller = AddressesTestController.new

    # enable a logger so that (e.g.) the benchmarking stuff runs, so we can get
    # a more accurate simulation of what happens in "real life".
    @controller.logger = Logger.new(nil)

    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @request.host = "www.nextangle.com"
  end

  def test_list
    # because pagination is deprecated
    ActiveSupport::Deprecation.silence do
      get :list
    end
    assert_equal "We only need to get this far!", @response.body.chomp
  end
end
