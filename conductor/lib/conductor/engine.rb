# frozen_string_literal: true

require "rails"
require "action_controller/railtie"
require "conductor"

module Conductor
  class Engine < Rails::Engine
    isolate_namespace Conductor
    config.eager_load_namespaces << Conductor
  end
end
