# frozen_string_literal: true

module QueJobsManager
  def setup
    require "sequel"
    ActiveJob::Base.queue_adapter = :que
  end

  def clear_jobs
    Que.clear!
  end

  def start_workers
    que_url = ENV["QUE_DATABASE_URL"] || "postgres:///active_jobs_que_int_test"
    uri = URI.parse(que_url)
    host = uri.host
    port = uri.port
    user = uri.user || ENV["USER"]
    pass = uri.password
    db   = uri.path[1..-1]

    psql = [].tap do |args|
      args << "PGPASSWORD=\"#{pass}\"" if pass
      args << "psql -X -U #{user} -t template1"
      args << "-h #{host}" if host
      args << "-p #{port}" if port
    end.join(" ")

    %x{#{psql} -c 'drop database if exists "#{db}"'}
    %x{#{psql} -c 'create database "#{db}"'}

    Que.connection = Sequel.connect(que_url)
    Que.migrate!(version: Que::Migrations::CURRENT_VERSION)

    @locker = Que::Locker.new(
      queues: ["integration_tests"],
      poll_interval: 0.5,
      worker_priorities: [nil]
    )

  rescue Sequel::DatabaseConnectionError
    puts "Cannot run integration tests for que. To be able to run integration tests for que you need to install and start postgresql.\n"
    status = ENV["CI"] ? false : true
    exit status
  end

  def stop_workers
    @locker.stop!
  end
end
