# frozen_string_literal: true

namespace :log do

  ##
  # Truncates all/specified log files
  # ENV['LOGS']
  #   - defaults to all environments log files i.e. 'development,test,production'
  #   - ENV['LOGS']=all truncates all files i.e. log/*.log
  #   - ENV['LOGS']='test,development' truncates only specified files
  desc "Truncates all/specified *.log files in log/ to zero bytes (specify which logs with LOGS=test,development)"
  task :clear do
    log_files.each do |file|
      clear_log_file(file)
    end
  end

  def log_files
    if ENV["LOGS"] == "all"
      FileList["log/*.log"]
    elsif ENV["LOGS"]
      log_files_to_truncate(ENV["LOGS"])
    else
      log_files_to_truncate(all_environments.join(","))
    end
  end

  def log_files_to_truncate(envs)
    envs.split(",")
        .map    { |file| "log/#{file.strip}.log" }
        .select { |file| File.exist?(file) }
  end

  def clear_log_file(file)
    f = File.open(file, "w")
    f.close
  end

  def all_environments
    Dir["config/environments/*.rb"].map { |fname| File.basename(fname, ".*") }
  end
end
