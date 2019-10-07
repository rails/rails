# -*- encoding: utf-8 -*-
# stub: actioncable 6.1.0.alpha ruby lib

Gem::Specification.new do |s|
  s.name = "actioncable".freeze
  s.version = "6.1.0.alpha"

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "changelog_uri" => "https://github.com/rails/rails/blob/v6.1.0.alpha/actioncable/CHANGELOG.md", "source_code_uri" => "https://github.com/rails/rails/tree/v6.1.0.alpha/actioncable" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Pratik Naik".freeze, "David Heinemeier Hansson".freeze]
  s.date = "2019-10-05"
  s.description = "Structure many real-time application concerns into channels over a single WebSocket connection.".freeze
  s.email = ["pratiknaik@gmail.com".freeze, "david@loudthinking.com".freeze]
  s.files = ["CHANGELOG.md".freeze, "MIT-LICENSE".freeze, "README.md".freeze, "app/assets/javascripts/action_cable.js".freeze, "lib/action_cable".freeze, "lib/action_cable.rb".freeze, "lib/action_cable/channel".freeze, "lib/action_cable/channel.rb".freeze, "lib/action_cable/channel/base.rb".freeze, "lib/action_cable/channel/broadcasting.rb".freeze, "lib/action_cable/channel/callbacks.rb".freeze, "lib/action_cable/channel/naming.rb".freeze, "lib/action_cable/channel/periodic_timers.rb".freeze, "lib/action_cable/channel/streams.rb".freeze, "lib/action_cable/channel/test_case.rb".freeze, "lib/action_cable/connection".freeze, "lib/action_cable/connection.rb".freeze, "lib/action_cable/connection/authorization.rb".freeze, "lib/action_cable/connection/base.rb".freeze, "lib/action_cable/connection/client_socket.rb".freeze, "lib/action_cable/connection/identification.rb".freeze, "lib/action_cable/connection/internal_channel.rb".freeze, "lib/action_cable/connection/message_buffer.rb".freeze, "lib/action_cable/connection/stream.rb".freeze, "lib/action_cable/connection/stream_event_loop.rb".freeze, "lib/action_cable/connection/subscriptions.rb".freeze, "lib/action_cable/connection/tagged_logger_proxy.rb".freeze, "lib/action_cable/connection/test_case.rb".freeze, "lib/action_cable/connection/web_socket.rb".freeze, "lib/action_cable/engine.rb".freeze, "lib/action_cable/gem_version.rb".freeze, "lib/action_cable/helpers".freeze, "lib/action_cable/helpers/action_cable_helper.rb".freeze, "lib/action_cable/remote_connections.rb".freeze, "lib/action_cable/server".freeze, "lib/action_cable/server.rb".freeze, "lib/action_cable/server/base.rb".freeze, "lib/action_cable/server/broadcasting.rb".freeze, "lib/action_cable/server/configuration.rb".freeze, "lib/action_cable/server/connections.rb".freeze, "lib/action_cable/server/worker".freeze, "lib/action_cable/server/worker.rb".freeze, "lib/action_cable/server/worker/active_record_connection_management.rb".freeze, "lib/action_cable/subscription_adapter".freeze, "lib/action_cable/subscription_adapter.rb".freeze, "lib/action_cable/subscription_adapter/async.rb".freeze, "lib/action_cable/subscription_adapter/base.rb".freeze, "lib/action_cable/subscription_adapter/channel_prefix.rb".freeze, "lib/action_cable/subscription_adapter/inline.rb".freeze, "lib/action_cable/subscription_adapter/postgresql.rb".freeze, "lib/action_cable/subscription_adapter/redis.rb".freeze, "lib/action_cable/subscription_adapter/subscriber_map.rb".freeze, "lib/action_cable/subscription_adapter/test.rb".freeze, "lib/action_cable/test_case.rb".freeze, "lib/action_cable/test_helper.rb".freeze, "lib/action_cable/version.rb".freeze, "lib/rails".freeze, "lib/rails/generators".freeze, "lib/rails/generators/channel".freeze, "lib/rails/generators/channel/USAGE".freeze, "lib/rails/generators/channel/channel_generator.rb".freeze, "lib/rails/generators/channel/templates".freeze, "lib/rails/generators/channel/templates/application_cable".freeze, "lib/rails/generators/channel/templates/application_cable/channel.rb.tt".freeze, "lib/rails/generators/channel/templates/application_cable/connection.rb.tt".freeze, "lib/rails/generators/channel/templates/channel.rb.tt".freeze, "lib/rails/generators/channel/templates/javascript".freeze, "lib/rails/generators/channel/templates/javascript/channel.js.tt".freeze, "lib/rails/generators/channel/templates/javascript/consumer.js.tt".freeze, "lib/rails/generators/channel/templates/javascript/index.js.tt".freeze, "lib/rails/generators/test_unit".freeze, "lib/rails/generators/test_unit/channel_generator.rb".freeze, "lib/rails/generators/test_unit/templates".freeze, "lib/rails/generators/test_unit/templates/channel_test.rb.tt".freeze]
  s.homepage = "https://rubyonrails.org".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.5.0".freeze)
  s.rubygems_version = "3.0.3".freeze
  s.summary = "WebSocket framework for Rails.".freeze

  s.installed_by_version = "3.0.3" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<activesupport>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<actionpack>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<nio4r>.freeze, ["~> 2.0"])
      s.add_runtime_dependency(%q<websocket-driver>.freeze, [">= 0.6.1"])
    else
      s.add_dependency(%q<activesupport>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<actionpack>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<nio4r>.freeze, ["~> 2.0"])
      s.add_dependency(%q<websocket-driver>.freeze, [">= 0.6.1"])
    end
  else
    s.add_dependency(%q<activesupport>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<actionpack>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<nio4r>.freeze, ["~> 2.0"])
    s.add_dependency(%q<websocket-driver>.freeze, [">= 0.6.1"])
  end
end
