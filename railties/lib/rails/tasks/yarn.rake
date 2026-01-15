# frozen_string_literal: true

require "rails/generators/js_package_manager"

namespace :javascript do
  desc "Install all JavaScript dependencies"
  task :install do
    valid_node_envs = %w[test development production]
    node_env = ENV.fetch("NODE_ENV") do
      valid_node_envs.include?(Rails.env) ? Rails.env : "production"
    end

    manager = Rails::Generators::JsPackageManager.detect(Rails.root)
    config = Rails::Generators::JsPackageManager::MANAGERS[manager]

    system({ "NODE_ENV" => node_env }, config[:install], exception: true)
  rescue Errno::ENOENT
    $stderr.puts "#{config[:name]} failed to execute."
    $stderr.puts "Ensure #{config[:name]} is installed and available in PATH."
    exit 1
  end
end

namespace :yarn do
  desc "Install all JavaScript dependencies as specified via Yarn"
  task install: "javascript:install"
end
