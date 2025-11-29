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
  config.eager_load       = false
  config.logger           = Logger.new($stdout)
  config.secret_key_base  = "secret_key_base"
end

Rails.application.initialize!

class BugTest < ActionView::TestCase
  def setup
    @tmp_path       = Pathname(Dir.mktmpdir)
    @old_view_path  = ActionController::Base.view_paths

    # config ActionController to search for templates at our tmp dir
    ActionController::Base.prepend_view_path @tmp_path
  end

  def teardown
    # delete the tmp dir with files
    FileUtils.rm_rf @tmp_path

    # restores the old view path
    ActionController::Base.view_paths = @old_view_path
  end

  helper do
    def template_name
      "main"
    end

    def partial_content(&block)
      File.write(@tmp_path.join("_partial.html.erb"), block.call)
    end

    def template_content(&block)
      File.write(@tmp_path.join("#{template_name}.html.erb"), block.call)
    end
  end

  def test_stuff
    partial_content do
      <<~ERB
        <p><%= arg_1 %></p>
        <p><%= arg_2 %></p>
        <p><%= arg_3 %></p>
      ERB
    end

    template_content do
      <<~ERB
        <div>
          <h1>Title</h1>
          <%= render partial: "partial", locals: { arg_1: "value1", arg_2: "value2", arg_3: "value3" } %>
        </div>
      ERB
    end

    render template: template_name

    element_contents = rendered.html.css("p").map(&:text)

    assert_equal %w[value1 value2 value3], element_contents
  end
end
