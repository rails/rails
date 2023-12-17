# frozen_string_literal: true

require "bundler/inline"
require "action_controller/railtie"
require "minitest/autorun"
require "rack/test"

class ContentTest < ActionDispatch::IntegrationTest
  class CharactersController < ActionController::Base
    def create
      render head: :no_content
    end
  end

  def test_params_without_content_type
    post "/characters", params: { name: "Muad'Dib" }
  end

  def test_params_with_html_content_type
    post "/users", as: :html, params: { name: "Muad'Dib" }
  end
end
