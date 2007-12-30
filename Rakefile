require 'rubygems'
require 'spec'
require 'spec/rake/spectask'

Spec::Rake::SpecTask.new do |t|
  t.spec_files = FileList['spec/**/*_spec.rb']
end

desc "Default task is to run specs"
task :default => :spec