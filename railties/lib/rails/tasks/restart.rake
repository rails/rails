require 'spring/client'

desc "Restart Rails and Spring"
task :restart do
  puts "Restarting Spring . . ."
  Spring::Client::Stop.call([])
  # Quick hack to run spring.
  Spring::Client::Run.call(["rake", "-e" "'puts'"])
end
