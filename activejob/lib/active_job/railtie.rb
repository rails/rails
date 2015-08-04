require 'global_id/railtie'
require 'active_job'

module ActiveJob
  # = Active Job Railtie
  class Railtie < Rails::Railtie # :nodoc:
    config.active_job = ActiveSupport::OrderedOptions.new

    initializer 'active_job.logger' do
      ActiveSupport.on_load(:active_job) { self.logger = ::Rails.logger }
    end

    initializer "active_job.set_configs" do |app|
      options = app.config.active_job
      options.queue_adapter ||= :inline

      ActiveSupport.on_load(:active_job) do
        options.each { |k,v| send("#{k}=", v) }
      end
    end

  end
end
