desc "List the gems that this rails application depends on"
task :gems => :environment do
  Rails.configuration.gems.each do |gem|
    puts "[#{gem.loaded? ? '*' : ' '}] #{gem.name} #{gem.requirement.to_s}"
  end
end

namespace :gems do
  desc "Installs all required gems for this application."
  task :install => :environment do
    require 'rubygems'
    require 'rubygems/gem_runner'
    Rails.configuration.gems.each { |gem| gem.install unless gem.loaded? }
  end

  desc "Unpacks the specified gem into vendor/gems."
  task :unpack do
    raise "Specify name of gem in the config.gems array with GEM=" if ENV['GEM'].blank?
    Rake::Task["environment"].invoke
    require 'rubygems'
    require 'rubygems/gem_runner'
    unless Rails.configuration.gems.select do |gem|
      if gem.loaded? && gem.name == ENV['GEM']
        gem.unpack_to(File.join(RAILS_ROOT, 'vendor', 'gems'))
        true
      end
    end.any?
      puts "No gem named #{ENV['GEM'].inspect} found."
    end
  end
end