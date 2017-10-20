# frozen_string_literal: true

require "abstract_unit"

module ApiWithHelper
  def my_helper
    "helper"
  end
end

class WithHelpersController < ActionController::API
  include ActionController::Helpers
  helper ApiWithHelper

  def with_helpers
    render plain: self.class.helpers.my_helper
  end
end

class SubclassWithHelpersController < WithHelpersController
  def with_helpers
    render plain: self.class.helpers.my_helper
  end
end

class WithHelpersTest < ActionController::TestCase
  tests WithHelpersController

  def test_with_helpers
    get :with_helpers

    assert_equal "helper", response.body
  end
end

class SubclassWithHelpersTest < ActionController::TestCase
  tests WithHelpersController

  def test_with_helpers
    get :with_helpers

    assert_equal "helper", response.body
  end
end
