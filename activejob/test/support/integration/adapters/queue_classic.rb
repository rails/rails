module QueueClassicJobsManager
  def setup
    return if ENV['AJ_QC_WAS_SETUP'] # skip setup if it ran already
    ENV['AJ_QC_WAS_SETUP'] = "1"

    ENV['QC_RAILS_DATABASE'] = 'false'
    ENV['QC_DATABASE_URL'] ||= 'postgres:///active_jobs_qc_int_test'
    ENV['QC_LISTEN_TIME']    = "0.5"
    uri = URI.parse(ENV['QC_DATABASE_URL'])
    user = uri.user||ENV['USER']
    pass = uri.password
    db   = uri.path[1..-1]
    %x{#{"PGPASSWORD=\"#{pass}\"" if pass} psql -c 'drop database if exists "#{db}"' -U #{user} -t template1}
    %x{#{"PGPASSWORD=\"#{pass}\"" if pass} psql -c 'create database "#{db}"' -U #{user} -t template1}
    ActiveJob::Base.queue_adapter = :queue_classic
    QC::Setup.create
  rescue PG::ConnectionBad
    puts "Cannot run integration tests for queue_classic. To be able to run integration tests for queue_classic you need to install and start postgresql.\n"
    exit
  end

  def clear_jobs
    QC::Queue.new("integration_tests").delete_all
  end

  def start_workers
    unless QC.respond_to?(:default_conn_adapter)
      QC::Conn.disconnect
    end

    @pid = fork do
      worker = QC::Worker.new(q_name: 'integration_tests')
      worker.start
    end
  end

  def stop_workers
    Process.kill 'HUP', @pid
  end
end
