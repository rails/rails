desc 'Prints out your Rack middleware stack'
task :middleware => :environment do
  ActionController::Dispatcher.middleware.active.each do |middleware|
    puts "use #{middleware.inspect}"
  end
  puts "run ActionController::Dispatcher.new"
end
