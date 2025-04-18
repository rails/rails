# frozen_string_literal: true

require "rails/application_controller"

class Rails::PwaController < Rails::ApplicationController # :nodoc:
  skip_forgery_protection
  content_security_policy false, only: :service_worker

  def service_worker
    render template: "pwa/service-worker", layout: false
  end

  def manifest
    render template: "pwa/manifest", layout: false
  end
end
