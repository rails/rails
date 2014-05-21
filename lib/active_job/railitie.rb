require 'active_model/global_id'
require 'active_job'

module ActiveJob
  # = Active Job Railtie
  class Railtie < Rails::Railtie # :nodoc:
    initializer 'active_job' do
      ActiveSupport.on_load(:active_job) { Base.logger = ::Rails.logger }
    end
  end
end