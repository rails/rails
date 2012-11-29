require 'cases/helper'
require 'active_support/testing/isolation'

class RailtieTest < ActiveModel::TestCase
  include ActiveSupport::Testing::Isolation

  def setup
    require 'active_model/railtie'

    @app ||= Class.new(::Rails::Application) do
      config.eager_load = false
      config.logger = Logger.new(STDOUT)
    end
  end

  test 'secure password is set to a default value in the development environment' do
    Rails.env = 'development'
    @app.initialize!

    assert_equal 10, ActiveModel::SecurePassword.cost
  end

  test 'secure password is set to a default value in the production environment' do
    Rails.env = 'production'
    @app.initialize!

    assert_equal 10, ActiveModel::SecurePassword.cost
  end

  test 'secure password is set to the minimum cost allowed in the test environment' do
    Rails.env = 'test'
    @app.initialize!

    assert_equal 1, ActiveModel::SecurePassword.cost
  end
end
