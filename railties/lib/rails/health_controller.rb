# frozen_string_literal: true

class Rails::HealthController < ActionController::Base # :nodoc:
  rescue_from(Exception) { render_down }

  def show
    render_up
  end

  private
    def render_up
      render html: html_status(color: "green")
    end

    def render_down
      render html: html_status(color: "red"), status: 500
    end

    def html_status(color:)
      %(<html><body style="background-color: #{color}"></body></html>).html_safe
    end
end
