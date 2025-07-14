# frozen_string_literal: true

require "active_record/associations/counter_cache_registry"

module ActiveRecord
  class Railtie < Rails::Railtie
    initializer "active_record.clear_counter_cache_registry_on_reload" do |app|
      app.config.to_prepare do
        ActiveRecord::Associations::CounterCacheRegistry.clear
      end
    end
  end
end