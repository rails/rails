# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  git_source(:github) { |repo| "https://github.com/#{repo}.git" }

  gem "rails"
  # If you want to test against edge Rails replace the previous line with this:
  # gem "rails", github: "rails/rails", branch: "main"

  gem "capybara"
  gem "propshaft"
  gem "selenium-webdriver", ">= 4.11"
  gem "sqlite3"
end

require "action_controller/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_text/engine"

class TestApp < Rails::Application
  config.load_defaults Rails::VERSION::STRING.to_f

  config.root = __dir__
  config.hosts << "example.org"
  config.eager_load = false
  config.session_store :cookie_store, key: "cookie_store_key"
  config.secret_key_base = "secret_key_base"
  config.consider_all_requests_local = true

  config.logger = Rails.logger = Logger.new($stdout)

  config.active_storage.service = :local
  config.active_storage.service_configurations = {
    local: {
      root: Dir.tmpdir,
      service: "Disk"
    }
  }

  routes.append do
    resources :articles, only: [:new, :create, :show]
  end
end

ENV["DATABASE_URL"] = "sqlite3::memory:"

Rails.application.initialize!

require ActiveStorage::Engine.root.join("db/migrate/20170806125915_create_active_storage_tables.rb").to_s
require ActionText::Engine.root.join("db/migrate/20180528164100_create_action_text_tables.rb").to_s

ActiveRecord::Schema.define do
  CreateActiveStorageTables.new.change
  CreateActionTextTables.new.change

  create_table :articles, force: true
end

class Article < ActiveRecord::Base
  has_rich_text :body
end

class ArticlesController < ActionController::Base
  class_attribute :template, default: DATA.read

  def new
    @article = Article.new

    render inline: template, formats: :html
  end

  def create
    @article = Article.create!(params.require(:article).permit(:body))

    redirect_to @article
  end

  def show
    @article = Article.find(params[:id])

    render html: @article.body
  end
end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]
end

Capybara.configure do |config|
  config.server = :webrick
  config.default_normalize_ws = true
end

require "rails/test_help"

class BugTest < ApplicationSystemTestCase
  test "bug" do
    visit new_article_path
    fill_in_rich_text_area with: "<div>Hello, world</div>"
    click_on "Create Article"

    assert_css ".trix-content div", text: "Hello, world"
  end
end

__END__
<html>
  <head>
    <script type="importmap">
      {
        "imports": {
          "trix": "<%= asset_path("trix.js") %>",
          "@rails/actiontext": "<%= asset_path("actiontext.js") %>"
        }
      }
    </script>
    <script type="module">
      import "trix"
      import "@rails/actiontext"
    </script>
  </head>
  <body>
    <%= form_with model: @article do |form| %>
      <%= form.rich_text_area :body %>
      <%= form.button %>
    <% end %>
  </body>
</html>
