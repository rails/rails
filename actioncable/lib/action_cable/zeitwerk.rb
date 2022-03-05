# frozen_string_literal: true

require "zeitwerk"

lib = File.expand_path("..", __dir__)

loader = Zeitwerk::Loader.new
loader.tag = "action_cable"

loader.push_dir(lib)

loader.ignore(
  __FILE__,
  "#{lib}/action_cable/gem_version.rb",
  "#{lib}/action_cable/version.rb",
  # lib/rails contains generators, templates, documentation, etc. Generators are
  # required on demand, so we can just ignore it all.
  "#{lib}/rails",
)

loader.do_not_eager_load(
  # Adapters are required and loaded on demand.
  "#{lib}/action_cable/subscription_adapter",
  "#{lib}/action_cable/test_helper.rb",
  "#{lib}/action_cable/test_case.rb",
  "#{lib}/action_cable/connection/test_case.rb",
  "#{lib}/action_cable/channel/test_case.rb"
)

loader.inflector.inflect("postgresql" => "PostgreSQL")

loader.setup
