require 'cases/helper'
require 'active_support/testing/isolation'

# The GlobalID gem has a silly requirement that necessitates the
# Rails::Application class to have a name method. Hacky, but makes the tests
# pass.
module Rails
  class Application
    class << self
      def name
        'test'
      end
    end
  end
end

class RailtieTest < ActiveModel::TestCase
  include ActiveSupport::Testing::Isolation

  def setup
    require 'active_model/railtie'

    # Set a fake logger to avoid creating the log directory automatically
    fake_logger = Logger.new(nil)

    @app ||= Class.new(::Rails::Application) do
      config.eager_load = false
      config.logger = fake_logger
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
