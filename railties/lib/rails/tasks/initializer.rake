desc "Prints out initializers for your application"
task initializer: :environment do
  Rails.application.initializers.tsort_each do |initializer|
    puts initializer.name
  end
end
