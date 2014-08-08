require 'sneakers/runner'

module SneakersJobsManager
  def clear_jobs
  end

  def start_workers
    cmd = %{cd #{Rails.root.to_s} && (RAILS_ENV=test AJADAPTER=sneakers WORKERS=ActiveJob::QueueAdapters::SneakersAdapter::JobWrapper bundle exec rake --trace sneakers:run)}
    `#{cmd}`
    while !Rails.root.join("tmp/sneakers.pid").exist? do
      sleep 0.5
    end
  end

  def stop_workers
    Process.kill 'TERM', File.open(Rails.root.join("tmp/sneakers.pid").to_s).read.to_i
  end
end
