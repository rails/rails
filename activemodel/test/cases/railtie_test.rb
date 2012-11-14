require 'cases/helper'
require 'active_support/testing/isolation'

class RailtieTest < ActiveModel::TestCase
  include ActiveSupport::Testing::Isolation

  def setup
    require 'rails/all'

    @app ||= Class.new(::Rails::Application).tap do |app|
      app.config.eager_load = false
    end
  end

  test 'secure password min_cost is false in the development environment' do
    Rails.env = 'development'
    @app.initialize!

    assert_equal false, ActiveModel::SecurePassword.min_cost
  end

  test 'secure password min_cost is true in the test environment' do
    Rails.env = 'test'
    @app.initialize!

    assert_equal true, ActiveModel::SecurePassword.min_cost
  end
end
