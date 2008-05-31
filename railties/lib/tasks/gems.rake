desc "List the gems that this rails application depends on"
task :gems => 'gems:base' do
  Rails.configuration.gems.each do |gem|
    code = gem.loaded? ? (gem.frozen? ? "F" : "I") : " "
    puts "[#{code}] #{gem.name} #{gem.requirement.to_s}"
  end
  puts
  puts "I = Installed"
  puts "F = Frozen"
end

namespace :gems do
  task :base do
    $rails_gem_installer = true
    Rake::Task[:environment].invoke
  end

  desc "Build any native extensions for unpacked gems"
  task :build do
    $rails_gem_installer = true
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
  task :install => :base do
    require 'rubygems'
    require 'rubygems/gem_runner'
    Rails.configuration.gems.each { |gem| gem.install unless gem.loaded? }
  end

  desc "Unpacks the specified gem into vendor/gems."
  task :unpack => :base do
    require 'rubygems'
    require 'rubygems/gem_runner'
    Rails.configuration.gems.each do |gem|
      next unless !gem.frozen? && (ENV['GEM'].blank? || ENV['GEM'] == gem.name)
      gem.unpack_to(File.join(RAILS_ROOT, 'vendor', 'gems')) if gem.loaded?
    end
  end
  
  namespace :unpack do
    desc "Unpacks the specified gems and its dependencies into vendor/gems"
    task :dependencies => :unpack do
      require 'rubygems'
      require 'rubygems/gem_runner'
      Rails.configuration.gems.each do |gem|
        next unless ENV['GEM'].blank? || ENV['GEM'] == gem.name
        gem.dependencies.each do |dependency|
          dependency.add_load_paths # double check that we have not already unpacked
          next if dependency.frozen?
          dependency.unpack_to(File.join(RAILS_ROOT, 'vendor', 'gems'))
        end
      end
    end
  end
end