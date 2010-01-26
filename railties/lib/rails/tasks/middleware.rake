desc 'Prints out your Rack middleware stack'
task :middleware => :environment do
  Rails.configuration.middleware.active.each do |middleware|
    puts "use #{middleware.inspect}"
  end
  puts "run #{Rails::Application.instance.class.name}.routes"
end
