# frozen_string_literal: true

require "isolation/abstract_unit"

class ActionViewTestCaseIntegrationTest < ActionView::TestCase
  include ActiveSupport::Testing::Isolation

  class HomeController < ActionController::Base
    def index; end

    def url_options
      {}
    end
  end

  setup do
    build_app

    app_file "config/routes.rb", <<~RUBY
      Rails.application.routes.draw do
        root to: "action_view_test_case_test/home#index"
      end
    RUBY

    require "#{app_path}/config/environment"

    HomeController.include(Rails.application.routes.url_helpers)
    @controller = HomeController.new
  end

  teardown :teardown_app

  test "can use url helpers" do
    assert_equal("/", root_path)
  end
end
