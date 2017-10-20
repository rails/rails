# frozen_string_literal: true

module QueueClassicJobsManager
  def setup
    ENV["QC_DATABASE_URL"] ||= "postgres:///active_jobs_qc_int_test"
    ENV["QC_RAILS_DATABASE"] = "false"
    ENV["QC_LISTEN_TIME"]    = "0.5"
    ActiveJob::Base.queue_adapter = :queue_classic
  end

  def clear_jobs
    QC::Queue.new("integration_tests").delete_all
  end

  def start_workers
    uri = URI.parse(ENV["QC_DATABASE_URL"])
    user = uri.user || ENV["USER"]
    pass = uri.password
    db   = uri.path[1..-1]
    %x{#{"PGPASSWORD=\"#{pass}\"" if pass} psql -c 'drop database if exists "#{db}"' -U #{user} -t template1}
    %x{#{"PGPASSWORD=\"#{pass}\"" if pass} psql -c 'create database "#{db}"' -U #{user} -t template1}
    QC::Setup.create

    QC.default_conn_adapter.disconnect
    QC.default_conn_adapter = nil
    @pid = fork do
      worker = QC::Worker.new(q_name: "integration_tests")
      worker.start
    end

  rescue PG::ConnectionBad
    puts "Cannot run integration tests for queue_classic. To be able to run integration tests for queue_classic you need to install and start postgresql.\n"
    exit
  end

  def stop_workers
    Process.kill "HUP", @pid
  end
end
