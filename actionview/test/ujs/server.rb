# frozen_string_literal: true

require "rack"
require "rails"
require "action_controller/railtie"
require "action_view/railtie"
require "blade"
require "json"

module UJS
  class Server < Rails::Application
    routes.append do
      get "/rails-ujs.js" => Blade::Assets.environment
      get "/" => "tests#index"
      match "/echo" => "tests#echo", via: :all
      get "/error" => proc { |env| [403, {}, []] }
    end

    config.cache_classes = false
    config.eager_load = false
    config.secret_key_base = "59d7a4dbd349fa3838d79e330e39690fc22b931e7dc17d9162f03d633d526fbb92dfdb2dc9804c8be3e199631b9c1fbe43fc3e4fc75730b515851849c728d5c7"
    config.paths["app/views"].unshift("#{Rails.root}/views")
    config.public_file_server.enabled = true
    config.logger = Logger.new(STDOUT)
    config.log_level = :error
  end
end

module TestsHelper
  def test_to(*names)
    names = ["/vendor/qunit.js", "settings"] + names
    names.map { |name| script_tag name }.join("\n").html_safe
  end

  def script_tag(src)
    src = "/test/#{src}.js" unless src.index("/")
    %(<script src="#{src}" type="text/javascript"></script>).html_safe
  end
end

class TestsController < ActionController::Base
  helper TestsHelper
  layout "application"

  def index
    render :index
  end

  def echo
    data = { params: params.to_unsafe_h }.update(request.env)

    if params[:content_type] && params[:content]
      render inline: params[:content], content_type: params[:content_type]
    elsif request.xhr?
      render json: JSON.generate(data)
    elsif params[:iframe]
      payload = JSON.generate(data).gsub("<", "&lt;").gsub(">", "&gt;")
      html = <<-HTML
        <script>
          if (window.top && window.top !== window)
            window.top.jQuery.event.trigger('iframe:loaded', #{payload})
        </script>
        <p>You shouldn't be seeing this. <a href="#{request.env['HTTP_REFERER']}">Go back</a></p>
      HTML

      render html: html.html_safe
    else
      render plain: "ERROR: #{request.path} requested without ajax", status: 404
    end
  end
end

Blade.initialize!
UJS::Server.initialize!
