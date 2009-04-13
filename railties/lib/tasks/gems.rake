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

namespace :gems do
  task :base do
    $gems_rake_task = true
    require 'rubygems'
    require 'rubygems/gem_runner'
    Rake::Task[:environment].invoke
  end

  desc "Build any native extensions for unpacked gems"
  task :build do
    $gems_build_rake_task = true
    Rake::Task['gems:unpack'].invoke
    current_gems.each &:build
  end

  desc "Installs all required gems."
  task :install => :base do
    current_gems.each &:install
  end

  desc "Unpacks all required gems into vendor/gems."
  task :unpack => :install do
    current_gems.each &:unpack
  end

  namespace :unpack do
    desc "Unpacks all required gems and their dependencies into vendor/gems."
    task :dependencies => :install do
      current_gems.each { |gem| gem.unpack(:recursive => true) }
    end
  end

  desc "Regenerate gem specifications in correct format."
  task :refresh_specs => :base do
    current_gems.each &:refresh
  end
end

def current_gems
  gems = Rails.configuration.gems
  gems = gems.select { |gem| gem.name == ENV['GEM'] } unless ENV['GEM'].blank?
  gems
end

def print_gem_status(gem, indent=1)
  code = case
    when gem.framework_gem? then 'R'
    when gem.frozen?        then 'F'
    when gem.installed?     then 'I'
    else                         ' '
  end
  puts "   "*(indent-1)+" - [#{code}] #{gem.name} #{gem.requirement.to_s}"
  gem.dependencies.each { |g| print_gem_status(g, indent+1) }
end
