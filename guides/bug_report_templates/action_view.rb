# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  gem "rails"
  # If you want to test against edge Rails replace the previous line with this:
  # gem "rails", github: "rails/rails", branch: "main"
end

require "action_controller/railtie"
require "action_view/railtie"
require "minitest/autorun"

class TestApp < Rails::Application
  config.load_defaults Rails::VERSION::STRING.to_f
  config.eager_load = false
  config.logger = Logger.new($stdout)
  config.secret_key_base = "secret_key_base"
end
Rails.application.initialize!

class BugTest < ActionView::TestCase
  setup do
    @view_path = Pathname.new(Dir.mktmpdir)
    ActionController::Base.prepend_view_path @view_path
  end

  teardown do
    @view_path.rmtree
  end

  helper do
    def upcase(value)
      value.upcase
    end
  end

  def test_action_view_render_template
    view_file "posts/index.html.erb", <<~ERB
      <h1>Posts</h1>

      <% posts.each do |post| %>
        <%= render partial: "posts/post", locals: { post: post } %>
      <% end %>
    ERB

    view_file "posts/_post.html.erb", <<~ERB
      <p><%= upcase(post) %></p>
    ERB

    render template: "posts/index", locals: { posts: ["hello world"] }

    assert_equal "HELLO WORLD", rendered.html.at("p").text
  end

  def test_action_view_render_inline
    render inline: <<~ERB, locals: { key: "value" }
      <p><%= upcase(key) %></p>
    ERB

    element = rendered.html.at("p")

    assert_equal "VALUE", element.text
  end

  private
    def view_file(filename, contents)
      pathname = @view_path.join(filename)
      pathname.dirname.mkpath
      pathname.write(contents.chomp)
    end
end
