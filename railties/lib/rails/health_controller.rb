# frozen_string_literal: true

# Built-in Health Check Endpoint
#
# Rails comes with a built-in health check endpoint that is reachable at the
# `/up` path. This endpoint will return a 200 if the app has booted with no
# exceptions, otherwise a 500 status code will be returned.
#
# In production, many services are required to report their status upstream,
# whether it's to an uptime monitor that will page an engineer when things go
# wrong, or a load balancer or Kubernetes controller used to determine a pods
# health. This health check is designed to be a one-size fits all that will work
# in many situations.
#
# For any newly generated Rails applications it will be enabled by default, but
# you can configure it anywhere you'd like in your "config/routes.rb":
#
# ```ruby
# Rails.application.routes.draw do
#   get "healthz" => "rails/health#show"
# end
# ```
#
# The health check will now be accessible via the `/healthz` path.
#
# NOTE: This endpoint is not designed to give the status of all of your
# service's dependencies, such as the database or redis cluster. It is also not
# recommended to use those for health checks, in general, as it can lead to
# situations where your application is being restarted due to a third-party
# service going bad. Ideally, you should design your application to handle those
# outages gracefully.
class Rails::HealthController < ActionController::Base
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
