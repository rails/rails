module QueueClassicJobsManager
  def setup
    ENV['QC_DATABASE_URL'] ||= 'postgres://localhost/active_jobs_qc_int_test'
    ENV['QC_LISTEN_TIME']    = "0.5"
    uri = URI.parse(ENV['QC_DATABASE_URL'])
    user = uri.user||ENV['USER']
    pass = uri.password
    db   = uri.path[1..-1]
    %x{#{"PGPASSWORD=\"#{pass}\"" if pass} psql -c 'drop database "#{db}"' -U #{user} -t template1}
    %x{#{"PGPASSWORD=\"#{pass}\"" if pass} psql -c 'create database "#{db}"' -U #{user} -t template1}
    ActiveJob::Base.queue_adapter = :queue_classic
    QC::Setup.create
  rescue PG::ConnectionBad
    puts "Cannot run integration tests for queue_classic. To be able to run integration tests for queue_classic you need to install and start postgresql.\n"
    exit
  end

  def clear_jobs
    QC::Queue.new("integration_tests").delete_all
    retried = false
  rescue => e
    puts "Got exception while trying to clear jobs: #{e.inspect}"
    if retried
      puts "Already retried. Raising exception"
      raise e
    else
      puts "Retrying"
      retried = true
      QC::Conn.connection = QC::Conn.connect
      retry
    end
  end

  def start_workers
    @pid = fork do
      QC::Conn.connection = QC::Conn.connect
      worker = QC::Worker.new(q_name: 'integration_tests')
      worker.start
    end
  end

  def stop_workers
    Process.kill 'HUP', @pid
  end
end
