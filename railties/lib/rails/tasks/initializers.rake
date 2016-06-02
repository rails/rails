desc "Print out all defined initializers in the order they are invoked by Rails."
task initializers: :environment do
  Rails.application.initializers.tsort_each do |initializer|
    puts "#{initializer.instance_variable_get(:@context).class} #{initializer.name.inspect}"
  end
end
