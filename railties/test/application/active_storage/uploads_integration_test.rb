# frozen_string_literal: true

require "isolation/abstract_unit"
require "rack/test"
require "rails-dom-testing"

module ApplicationTests
  class UploadsIntegrationTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods
    include Rails::Dom::Testing::Assertions

    self.file_fixture_path = "#{RAILS_FRAMEWORK_ROOT}/activestorage/test/fixtures/files"

    def setup
      build_app
    end

    def teardown
      teardown_app
    end

    def test_creating_new_upload
      rails "active_storage:install"

      rails "generate", "model", "user", "name:string", "avatar:attachment"
      rails "db:migrate"

      app_file "config/routes.rb", <<~RUBY
        Rails.application.routes.draw do
          resources :users, only: [:show, :create]
        end
      RUBY

      app_file "app/controllers/users_controller.rb", <<~RUBY
        class UsersController < ApplicationController
          def show
            @user = User.find(params[:id])
            render :show
          end

          def create
            @user = User.new(user_params)

            if @user.save
              redirect_to user_url(@user), notice: "User was successfully created."
            else
              render :new, status: :unprocessable_entity
            end
          end

          private
            def user_params
              params.expect(user: [:name, :avatar])
            end
        end
      RUBY

      app_file "app/views/users/show.html.erb", <<~ERB
        <p><%= @user.name %></p>
        <p><%= image_tag @user.avatar %></p>
      ERB

      app("development")

      post "/users", user: { name: "zomg", avatar: Rack::Test::UploadedFile.new(file_fixture("racecar.jpg")) }
      assert_equal 302, last_response.status

      get "/users/1"
      assert_equal 200, last_response.status
      assert_select "p", text: "zomg"
      assert_select "img", count: 1
    end

    private
      def document_root_element
        Nokogiri::HTML5.parse(last_response.body)
      end
  end
end
