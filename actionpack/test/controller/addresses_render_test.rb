require 'abstract_unit'
require 'logger'

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
  def self.controller_name; "addresses"; end
  def self.controller_path; "addresses"; end
end

class AddressesTest < ActionController::TestCase
  tests AddressesTestController

  def setup
    super
    # enable a logger so that (e.g.) the benchmarking stuff runs, so we can get
    # a more accurate simulation of what happens in "real life".
    @controller.logger = Logger.new(nil)

    @request.host = "www.nextangle.com"
  end

  def test_list
    get :list
    assert_equal "We only need to get this far!", @response.body.chomp
  end
end
