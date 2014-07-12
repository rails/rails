require 'rake/testtask'
require 'rubygems/package_task'

desc "Default Task"
task default: [ :test ]

# Run the unit tests
Rake::TestTask.new { |t|
  t.libs << "test"
  t.pattern = 'test/**/*_test.rb'
  t.warning = true
  t.verbose = true
}

namespace :test do
  task :isolated do
    Dir.glob("test/**/*_test.rb").all? do |file|
      sh(Gem.ruby, '-w', '-Ilib:test', file)
    end or raise "Failures"
  end
end

spec = eval(File.read('actionmailer.gemspec'))

Gem::PackageTask.new(spec) do |p|
  p.gem_spec = spec
end

desc "Release to rubygems"
task release: :package do
  require 'rake/gemcutter'
  Rake::Gemcutter::Tasks.new(spec).define
  Rake::Task['gem:push'].invoke
end
