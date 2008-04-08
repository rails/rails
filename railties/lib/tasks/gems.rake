desc "List the gems that this rails application depends on"
task :gems => :environment do
  Rails.configuration.gems.each do |gem|
    code = gem.loaded? ? (gem.frozen? ? "F" : "I") : " "
    puts "[#{code}] #{gem.name} #{gem.requirement.to_s}"
  end
  puts
  puts "I = Installed"
  puts "F = Frozen"
end

namespace :gems do
  desc "Build any native extensions for unpacked gems"
  task :build do
    require 'rails/gem_builder'
    Dir[File.join(RAILS_ROOT, 'vendor', 'gems', '*')].each do |gem_dir|
      spec_file = File.join(gem_dir, '.specification')
      next unless File.exists?(spec_file)
      specification = YAML::load_file(spec_file)
      next unless ENV['GEM'].blank? || ENV['GEM'] == specification.name
      Rails::GemBuilder.new(specification, gem_dir).build_extensions
      puts "Built gem: '#{gem_dir}'"
    end
  end
  
  desc "Installs all required gems for this application."
  task :install => :environment do
    require 'rubygems'
    require 'rubygems/gem_runner'
    Rails.configuration.gems.each { |gem| gem.install unless gem.loaded? }
  end

  desc "Unpacks the specified gem into vendor/gems."
  task :unpack => :environment do
    require 'rubygems'
    require 'rubygems/gem_runner'
    Rails.configuration.gems.each do |gem|
      next unless !gem.frozen? && (ENV['GEM'].blank? || ENV['GEM'] == gem.name)
      gem.unpack_to(File.join(RAILS_ROOT, 'vendor', 'gems')) if gem.loaded?
    end
  end
end