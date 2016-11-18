module QueJobsManager
  def setup
    require "sequel"
    ActiveJob::Base.queue_adapter = :que
    Que.mode = :off
    Que.worker_count = 1
  end

  def clear_jobs
    Que.clear!
  end

  def start_workers
    que_url = ENV["QUE_DATABASE_URL"] || "postgres:///active_jobs_que_int_test"
    uri = URI.parse(que_url)
    user = uri.user || ENV["USER"]
    pass = uri.password
    db   = uri.path[1..-1]
    %x{#{"PGPASSWORD=\"#{pass}\"" if pass} psql -c 'drop database if exists "#{db}"' -U #{user} -t template1}
    %x{#{"PGPASSWORD=\"#{pass}\"" if pass} psql -c 'create database "#{db}"' -U #{user} -t template1}
    Que.connection = Sequel.connect(que_url)
    Que.migrate!

    @thread = Thread.new do
      loop do
        Que::Job.work
        sleep 0.5
      end
    end

  rescue Sequel::DatabaseConnectionError
    puts "Cannot run integration tests for que. To be able to run integration tests for que you need to install and start postgresql.\n"
    exit
  end

  def stop_workers
    @thread.kill
  end
end
