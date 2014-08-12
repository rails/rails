case ENV['AJADAPTER']
when "delayed_job"
  ActiveJob::Base.queue_adapter = :delayed_job
when "sidekiq"
  ActiveJob::Base.queue_adapter = :sidekiq
when "resque"
  ActiveJob::Base.queue_adapter = :resque
  Resque.redis = Redis::Namespace.new 'active_jobs_int_test', redis: Redis.connect(url: "tcp://127.0.0.1:6379/12", :thread_safe => true)
  Resque.logger = Rails.logger
when 'qu'
  ActiveJob::Base.queue_adapter = :qu
  ENV['REDISTOGO_URL'] = "tcp://127.0.0.1:6379/12"
  backend = Qu::Backend::Redis.new
  backend.namespace = "active_jobs_int_test"
  Qu.backend  = backend
  Qu.logger   = Rails.logger
  Qu.interval = 0.5
when 'que'
  ActiveJob::Base.queue_adapter = :que
  QUE_URL = ENV['QUE_DATABASE_URL'] || 'postgres://localhost/active_jobs_que_int_test'
  uri = URI.parse(QUE_URL)
  user = uri.user||ENV['USER']
  pass = uri.password
  db   = uri.path[1..-1]
  %x{#{"PGPASSWORD=\"#{pass}\"" if pass} psql -c 'drop database "#{db}"' -U #{user} -t template1}
  %x{#{"PGPASSWORD=\"#{pass}\"" if pass} psql -c 'create database "#{db}"' -U #{user} -t template1}
  Que.connection = Sequel.connect(QUE_URL)
  Que.migrate!
  Que.mode = :off
  Que.worker_count = 1
when 'queue_classic'
  ENV['QC_DATABASE_URL'] ||= 'postgres://localhost/active_jobs_qc_int_test'
  ENV['QC_LISTEN_TIME']    = "0.5"
  ActiveJob::Base.queue_adapter = :queue_classic
  uri = URI.parse(ENV['QC_DATABASE_URL'])
  user = uri.user||ENV['USER']
  pass = uri.password
  db   = uri.path[1..-1]
  %x{#{"PGPASSWORD=\"#{pass}\"" if pass} psql -c 'drop database "#{db}"' -U #{user} -t template1}
  %x{#{"PGPASSWORD=\"#{pass}\"" if pass} psql -c 'create database "#{db}"' -U #{user} -t template1}
  QC::Setup.create
when 'sidekiq'
  ActiveJob::Base.queue_adapter = :sidekiq
when 'sneakers'
  ActiveJob::Base.queue_adapter = :sneakers
  Sneakers.configure  :heartbeat => 2,
                      :amqp => 'amqp://guest:guest@localhost:5672',
                      :vhost => '/',
                      :exchange => 'active_jobs_sneakers_int_test',
                      :exchange_type => :direct,
                      :daemonize => true,
                      :threads => 1,
                      :workers => 1,
                      :pid_path => Rails.root.join("tmp/sneakers.pid").to_s,
                      :log => Rails.root.join("log/sneakers.log").to_s
when 'sucker_punch'
  ActiveJob::Base.queue_adapter = :sucker_punch
when 'backburner'
  ActiveJob::Base.queue_adapter = :backburner
  Backburner.configure do |config|
    config.logger = Rails.logger
  end
else
  ActiveJob::Base.queue_adapter = nil
end
