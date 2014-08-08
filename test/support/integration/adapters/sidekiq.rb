require 'sidekiq/launcher'
require 'sidekiq/api'

module SidekiqJobsManager
  def clear_jobs
    Sidekiq::Queue.new("active_jobs_default").clear
  end

  def start_workers
    options = {:queues=>["active_jobs_default"], :concurrency=>1, :environment=>"test", :timeout=>8, :daemon=>true, :strict=>true}
    @launcher = Sidekiq::Launcher.new(options)
    @launcher.run
  end

  def stop_workers
    @launcher.stop
  end
end

