# frozen_string_literal: true

require "isolation/abstract_unit"
require "rack/test"

module ApplicationTests
  class MiddlewareStrictSafeHTTPMethodsTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    SAFE_VERBS = [:get, :head, :options]
    UNSAFE_VERBS = [:put, :delete, :post, :patch]
    VERBS = SAFE_VERBS + UNSAFE_VERBS

    def setup
      build_app

      app_file "app/models/post.rb", <<~RUBY
        class Post < ApplicationRecord
        end
      RUBY

      app_file "app/controllers/posts_controller.rb", <<~RUBY
        class PostsController < ApplicationController
          def read
            render plain: Post.first.title
          end

          def write
            post = Post.create! title: "New post \#{SecureRandom.uuid}"
            render plain: post.title
          end
        end
      RUBY

      app_file "config/routes.rb", <<~RUBY
        Rails.application.routes.draw do
          match "/read" => "posts#read", via: #{VERBS.inspect}
          match "/write" => "posts#write", via: #{VERBS.inspect}
        end
      RUBY

      add_to_config <<~RUBY
        config.active_record.strict_safe_http_methods = true
      RUBY

      require "#{rails_root}/config/environment"

      ActiveRecord::Base.establish_connection
      ActiveRecord::Migration.verbose = false
      ActiveRecord::Schema.define(version: 1) do
        create_table :posts do |t|
          t.string :title
        end
      end

      extend Rack::Test::Methods
    end

    def teardown
      teardown_app
    end

    VERBS.each do |verb|
      test "#{verb.upcase} allows read" do
        Post.create! title: "Hello"

        send verb, "/read"

        assert_equal 200, last_response.status
        assert_equal "Hello", last_response.body unless verb == :head
      end
    end

    SAFE_VERBS.each do |verb|
      test "#{verb.upcase} disallows write" do
        send verb, "/write"

        assert_equal 500, last_response.status
      end
    end

    UNSAFE_VERBS.each do |verb|
      test "#{verb.upcase} allows write" do
        send verb, "/write"

        assert_equal 200, last_response.status
        assert_equal Post.last.title, last_response.body
      end
    end
  end
end
