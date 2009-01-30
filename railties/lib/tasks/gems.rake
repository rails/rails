desc "List the gems that this rails application depends on"
task :gems => 'gems:base' do
  Rails.configuration.gems.each do |gem|
    print_gem_status(gem)
  end
  puts
  puts "I = Installed"
  puts "F = Frozen"
  puts "R = Framework (loaded before rails starts)"
end

def print_gem_status(gem, indent=1)
  code = gem.loaded? ? (gem.frozen? ? (gem.framework_gem? ? "R" : "F") : "I") : " "
  puts "   "*(indent-1)+" - [#{code}] #{gem.name} #{gem.requirement.to_s}"
  gem.dependencies.each { |g| print_gem_status(g, indent+1)} if gem.loaded?
end

namespace :gems do
  task :base do
    $rails_rake_task = true
    Rake::Task[:environment].invoke
  end

  desc "Build any native extensions for unpacked gems"
  task :build do
    $rails_rake_task = true
    require 'rails/gem_builder'
    Dir[File.join(Rails::GemDependency.unpacked_path, '*')].each do |gem_dir|
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
      gem.unpack_to(Rails::GemDependency.unpacked_path) if gem.loaded?
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
          next if dependency.frozen?
          dependency.unpack_to(Rails::GemDependency.unpacked_path)
        end
      end
    end
  end

  desc "Regenerate gem specifications in correct format."
  task :refresh_specs => :base do
    require 'rubygems'
    require 'rubygems/gem_runner'
    Rails::VendorGemSourceIndex.silence_spec_warnings = true
    Rails.configuration.gems.each do |gem|
      next unless gem.frozen? && (ENV['GEM'].blank? || ENV['GEM'] == gem.name)
      gem.refresh_spec(Rails::GemDependency.unpacked_path) if gem.loaded?
    end
  end
end