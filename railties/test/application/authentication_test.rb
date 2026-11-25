# frozen_string_literal: true

require "isolation/abstract_unit"
require "rack/test"

module ApplicationTests
  class AuthenticationTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      build_app

      rails "generate", "authentication"
      rails "db:migrate"

      app_file "app/controllers/accounts_controller.rb", <<~RUBY
        class AccountsController < ApplicationController
          def show
            render plain: Current.user.email_address
          end
        end
      RUBY

      app_file "config/routes.rb", <<~RUBY
        Rails.application.routes.draw do
          resource :session, only: [ :new, :create, :destroy ]
          resource :account, only: :show
          root "accounts#show"
        end
      RUBY
    end

    def teardown
      teardown_app
    end

    def test_session_cookie_does_not_authenticate_a_later_session_with_the_same_id
      app("development")

      alice = User.create!(email_address: "alice@example.com", password: "secret")
      bob = User.create!(email_address: "bob@example.com", password: "secret")

      post "/session", email_address: "alice@example.com", password: "secret"
      alice_cookies = rack_mock_session.cookie_jar.to_hash
      get "/account"
      assert_equal "alice@example.com", last_response.body

      alice_session = alice.sessions.sole
      alice_session.destroy!

      clear_cookies
      post "/session", email_address: "bob@example.com", password: "secret"
      bob_cookies = rack_mock_session.cookie_jar.to_hash

      # Give Bob's session the ID that Alice's session had, as happens when
      # IDs are reused (for example, after a database restore).
      bob.sessions.sole.update_column(:id, alice_session.id)

      replace_cookies alice_cookies
      get "/account"
      assert_redirected_to_sign_in "Alice's old cookie authenticated as #{last_response.body.inspect}"

      replace_cookies bob_cookies
      get "/account"
      assert_equal 200, last_response.status
      assert_equal "bob@example.com", last_response.body
    end

    private
      def replace_cookies(cookies)
        clear_cookies
        cookies.each { |name, value| set_cookie "#{name}=#{value}" }
      end

      def assert_redirected_to_sign_in(message = nil)
        assert_equal 302, last_response.status, message
        assert_equal "http://example.org/session/new", last_response.location
      end
  end
end
