# frozen_string_literal: true

desc "Print out all defined initializers in the order they are invoked by Rails."
task initializers: :environment do
  Rails.application.initializers.tsort_each do |initializer|
    puts "#{initializer.context_class}.#{initializer.name}"
  end
end
