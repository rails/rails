class ActiveRecord::Tasks::DatabaseTasks
  def self.create(configuration)
    if File.exist?(configuration['database'])
      $stderr.puts "#{configuration['database']} already exists"
      return
    end

    ActiveRecord::Base.establish_connection(configuration)
    ActiveRecord::Base.connection
  rescue Exception => e
    $stderr.puts e, *(e.backtrace)
    $stderr.puts "Couldn't create database for #{configuration.inspect}"
  end
end
