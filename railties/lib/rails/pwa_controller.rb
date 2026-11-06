# frozen_string_literal: true

require "rails/application_controller"

class Rails::PwaController < Rails::ApplicationController # :nodoc:
  skip_forgery_protection

  def service_worker
    render template: "pwa/service-worker", layout: false, formats: :js
  end

  def manifest
    render template: "pwa/manifest", layout: false, formats: :json
  end

  def offline
    render template: "pwa/offline", layout: false
  end
end
