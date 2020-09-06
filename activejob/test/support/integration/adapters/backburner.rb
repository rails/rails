# frozen_string_literal: true

module BackburnerJobsManager
  def setup
    ActiveJob::Base.queue_adapter = :backburner
    Backburner.configure do |config|
      config.beanstalk_url = ENV['BEANSTALK_URL'] if ENV['BEANSTALK_URL']
      config.logger = Rails.logger
    end
    unless can_run?
      puts "Cannot run integration tests for backburner. To be able to run integration tests for backburner you need to install and start beanstalkd.\n"
      status = ENV['CI'] ? false : true
      exit status
    end
  end

  def clear_jobs
    tube.clear
  end

  def start_workers
    @thread = Thread.new { Backburner.work 'integration-tests' } # backburner dasherizes the queue name
  end

  def stop_workers
    @thread.kill
  end

  def tube
    @tube ||= Beaneater::Tube.new(@worker.connection, 'backburner.worker.queue.integration-tests') # backburner dasherizes the queue name
  end

  def can_run?
    begin
      @worker = Backburner::Worker.new
    rescue
      return false
    end
    true
  end
end
