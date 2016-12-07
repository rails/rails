# frozen_string_literal: true

require "isolation/abstract_unit"
require "rack/test"
require "minitest/mock"

require "action_view"

class PerRequestDigestCacheTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation
  include Rack::Test::Methods

  setup do
    build_app
    add_to_config "config.consider_all_requests_local = true"

    app_file "app/models/customer.rb", <<-RUBY
      class Customer < Struct.new(:name, :id)
        extend ActiveModel::Naming
        include ActiveModel::Conversion

        def cache_key
          [ name, id ].join("/")
        end
      end
    RUBY

    app_file "config/routes.rb", <<-RUBY
      Rails.application.routes.draw do
        resources :customers, only: :index
      end
    RUBY

    app_file "app/controllers/customers_controller.rb", <<-RUBY
      class CustomersController < ApplicationController
        self.perform_caching = true

        def index
          render [ Customer.new('david', 1), Customer.new('dingus', 2) ]
        end
      end
    RUBY

    app_file "app/views/customers/_customer.html.erb", <<-ERB
      <% cache customer do %>
        <%= customer.name %>
      <% end %>
    ERB

    require "#{app_path}/config/environment"
  end

  teardown :teardown_app

  test "digests are reused when rendering the same template twice" do
    get "/customers"
    assert_equal 200, last_response.status

    values = ActionView::Digestor.cache.values
    assert_equal [ "effc8928d0b33535c8a21d24ec617161" ], values
    assert_equal %w(david dingus), last_response.body.split.map(&:strip)
  end

  test "template digests are cleared before a request" do
    assert_called(ActionView::Digestor, :clear_cache) do
      get "/customers"
      assert_equal 200, last_response.status
    end
  end

  test "recompiles updated template" do
    get "/customers"
    assert_no_match "Hi", last_response.body
    app_file "app/views/customers/_customer.html.erb", <<-ERB
      <% cache customer do %>
        Hi <%= customer.name %>!
      <% end %>
    ERB
    get "/customers"
    assert_match "Hi ", last_response.body
  end

  test "does not recompile not-modified templates" do
    get "/customers"
    assert_no_changes -> { ActionView::CompiledTemplates.instance_methods } do
      get "/customers"
    end
  end

  test "does not leak memory in templates cache" do
    app_file "app/views/customers/_customer.html.erb",
      "<%= lookup_context.view_paths.paths.sum { |x| x.instance_variable_get(:@cache).size } %>"
    assert_no_changes -> { get("/customers") && last_response.body } do
      # noop
    end
  end
end
