require "rails"
require "action_cable"
require "action_cable/helpers/action_cable_helper"
require "active_support/core_ext/hash/indifferent_access"

module ActionCable
  class Engine < Rails::Engine # :nodoc:
    config.action_cable = ActiveSupport::OrderedOptions.new
    config.action_cable.mount_path = ActionCable::INTERNAL[:default_mount_path]

    config.eager_load_namespaces << ActionCable

    initializer "action_cable.helpers" do
      ActiveSupport.on_load(:action_view) do
        include ActionCable::Helpers::ActionCableHelper
      end
    end

    initializer "action_cable.logger" do
      ActiveSupport.on_load(:action_cable) { self.logger ||= ::Rails.logger }
    end

    initializer "action_cable.set_configs" do |app|
      options = app.config.action_cable

      @@previous_servers ||= []

      # Automatically set appropriate allowed_request_origins when running `rails s` in development
      if defined?(Rails::Server) && ::Rails.env.development? && options.allowed_request_origins.nil?
        begin
          local_ips = ["localhost"]

          # Find the server object our app is running under
          rails_servers = ObjectSpace.each_object(Rails::Server)
          servers = rails_servers.select { |rails_server| rails_server.instance_variable_get(:@app) == app }
          servers = rails_servers.to_a if servers.empty?
          servers.reject! { |srv| @@previous_servers.include?(srv) }
          server = servers.last

          # In case other recently-used server objects haven't been GC'd yet, keep track of what is current
          @@previous_servers << server

          # Get any binding that was specified
          server_binding = server.instance_variable_get(:@options)[:Host]

          if server_binding != nil
            if server_binding == "0.0.0.0"
              # Filter to include only private IPv4 addresses (those not routable on the Internet)
              local_prefixes = ["10.", "127.", "172.16.", "172.17.", "172.18.", "172.19.",
                "172.20.", "172.21.", "172.22.", "172.23.", "172.24.", "172.25.", "172.26.",
                "172.27.", "172.28.", "172.29.", "172.30.", "172.31.", "169.254.", "192.168."]
              local_addresses = Socket.ip_address_list.select do |addr|
                addr.ipv4? && local_prefixes.inject(false) do |is_routable, prefix|
                  is_routable || addr.ip_address.starts_with?(prefix)
                end
              end
              local_ips += local_addresses.map(&:ip_address)
            else
              # rails s -b with a static IP address
              local_ips = [server_binding]
            end
            if local_ips.length > 0
              puts "Setting Action Cable allowed_request_origins for #{local_ips.length > 1 ? "these addresses:" : local_ips.first}"
              puts "  #{local_ips.join("\n  ")}" if local_ips.length > 1
            end
          end
        rescue => e
          puts "Unable to automatically set allowed_request_origins."
          Rails.logger.warn "Unable to automatically set allowed_request_origins:"
          Rails.logger.warn "  #{e}"
        ensure
          options.allowed_request_origins = local_ips.map { |ip| Regexp.new("https?:\/\/#{ip}:\\d+") }
        end
      end

      app.paths.add "config/cable", with: "config/cable.yml"

      ActiveSupport.on_load(:action_cable) do
        if (config_path = Pathname.new(app.config.paths["config/cable"].first)).exist?
          self.cable = Rails.application.config_for(config_path).with_indifferent_access
        end

        previous_connection_class = self.connection_class
        self.connection_class = -> { 'ApplicationCable::Connection'.safe_constantize || previous_connection_class.call }

        options.each { |k,v| send("#{k}=", v) }
      end
    end

    initializer "action_cable.routes" do
      config.after_initialize do |app|
        config = app.config
        unless config.action_cable.mount_path.nil?
          app.routes.prepend do
            mount ActionCable.server => config.action_cable.mount_path, internal: true
          end
        end
      end
    end

    initializer "action_cable.set_work_hooks" do |app|
      ActiveSupport.on_load(:action_cable) do
        ActionCable::Server::Worker.set_callback :work, :around, prepend: true do |_, inner|
          app.executor.wrap do
            # If we took a while to get the lock, we may have been halted
            # in the meantime. As we haven't started doing any real work
            # yet, we should pretend that we never made it off the queue.
            unless stopping?
              inner.call
            end
          end
        end

        wrap = lambda do |_, inner|
          app.executor.wrap(&inner)
        end
        ActionCable::Channel::Base.set_callback :subscribe, :around, prepend: true, &wrap
        ActionCable::Channel::Base.set_callback :unsubscribe, :around, prepend: true, &wrap

        app.reloader.before_class_unload do
          ActionCable.server.restart
        end
      end
    end
  end
end
