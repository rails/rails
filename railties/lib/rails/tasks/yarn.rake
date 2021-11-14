# frozen_string_literal: true

namespace :yarn do
  desc "Install all JavaScript dependencies as specified via Yarn"
  task :install do
    # Install only production deps when for not usual envs.
    valid_node_envs = %w[test development production]
    node_env = ENV.fetch("NODE_ENV") do
      valid_node_envs.include?(Rails.env) ? Rails.env : "production"
    end

    yarn_flags =
      if `yarn --version`.start_with?("1")
        "--no-progress --frozen-lockfile"
      else
        "--immutable"
      end

    system(
      { "NODE_ENV" => node_env },
      "yarn install #{yarn_flags}",
      exception: true
    )
  rescue Errno::ENOENT
    $stderr.puts "yarn install failed to execute."
    $stderr.puts "Ensure yarn is installed and `yarn --version` runs without errors."
    exit 1
  end
end
