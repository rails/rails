namespace :log do
  desc "Truncates all *.log files in log/ to zero bytes"
  task :clear do
    FileList["log/*.log"].each do |log_file|
      f = File.open(log_file, "w")
      f.close
    end
  end
end

desc "Tail the rails environment log file"
task :tail, [:lines] => :environment do |t, args|
  args.with_defaults(:lines => 100)
  log_file = Rails.root.join("log/#{Rails.env.downcase}.log").to_s
  if system('tail', '-f', "-n #{args.lines}", log_file).nil?
    if RUBY_PLATFORM =~ /(:?mswin|mingw)/
      warn "Sorry, rake tail is not available on windows"
    else
      warn "Sorry, the tail command may not be available in your operating system"
    end
  end
end