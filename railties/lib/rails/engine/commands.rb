# frozen_string_literal: true

unless defined?(APP_PATH)
  if File.exist?(File.expand_path('test/dummy/config/application.rb', ENGINE_ROOT))
    APP_PATH = File.expand_path('test/dummy/config/application', ENGINE_ROOT)
  end
end

require 'rails/commands'
