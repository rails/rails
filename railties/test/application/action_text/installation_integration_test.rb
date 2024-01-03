# frozen_string_literal: true

require "isolation/abstract_unit"
require "rack/test"

module ApplicationTests
  class InstallationIntegrationTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      build_app
    end

    def teardown
      teardown_app
    end

    def test_renders_actionable_exception_page_when_action_text_not_installed
      app "development"
      app_file "config/routes.rb", <<~RUBY
        Rails.application.routes.draw do
          post "/rich_texts" => "rich_texts#create"
        end
      RUBY
      app_file "app/controllers/rich_texts_controller.rb", <<~RUBY
        class RichTextsController < ActionController::Base
          def create
            ActionText::RichText.create!
          end
        end
      RUBY

      post "/rich_texts"

      assert_equal 500, last_response.status
      assert_match "To resolve this issue run: bin/rails action_text:install", last_response.body
    end
  end
end
