# frozen_string_literal: true

require "cases/helper"
require "active_support/testing/isolation"

class RailtieTest < ActiveModel::TestCase
  include ActiveSupport::Testing::Isolation

  def setup
    require "active_model/railtie"

    # Set a fake logger to avoid creating the log directory automatically
    fake_logger = Logger.new(nil)

    @app ||= Class.new(::Rails::Application) do
      config.eager_load = false
      config.logger = fake_logger
    end
  end

  test "secure password min_cost is false in the development environment" do
    Rails.env = "development"
    @app.initialize!

    assert_equal false, ActiveModel::SecurePassword.min_cost
  end

  test "secure password min_cost is true in the test environment" do
    Rails.env = "test"
    @app.initialize!

    assert_equal true, ActiveModel::SecurePassword.min_cost
  end

  test "i18n customize full message defaults to false" do
    @app.initialize!

    assert_equal false, ActiveModel::Error.i18n_customize_full_message
  end

  test "i18n customize full message can be disabled" do
    @app.config.active_model.i18n_customize_full_message = false
    @app.initialize!

    assert_equal false, ActiveModel::Error.i18n_customize_full_message
  end

  test "i18n customize full message can be enabled" do
    @app.config.active_model.i18n_customize_full_message = true
    @app.initialize!

    assert_equal true, ActiveModel::Error.i18n_customize_full_message
  end
end
