gem 'rdoc', '>= 2.5.9'
require 'rdoc'
require 'rake'
require 'rake/testtask'
require 'rdoc/task'
require 'rake/packagetask'
require 'rake/gempackagetask'

desc "Default Task"
task :default => [ :test ]

# Run the unit tests
Rake::TestTask.new { |t|
  t.libs << "test"
  t.pattern = 'test/**/*_test.rb'
  t.warning = true
}

namespace :test do
  task :isolated do
    ruby = File.join(*RbConfig::CONFIG.values_at('bindir', 'RUBY_INSTALL_NAME'))
    Dir.glob("test/**/*_test.rb").all? do |file|
      system(ruby, '-Ilib:test', file)
    end or raise "Failures"
  end
end

# Generate the RDoc documentation
RDoc::Task.new { |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.title    = "Action Mailer -- Easy email delivery and testing"
  rdoc.options << '--charset' << 'utf-8'
  rdoc.options << '-f' << 'horo'
  rdoc.options << '--main' << 'README.rdoc'
  rdoc.rdoc_files.include('README.rdoc', 'CHANGELOG')
  rdoc.rdoc_files.include('lib/action_mailer.rb')
  rdoc.rdoc_files.include('lib/action_mailer/*.rb')
  rdoc.rdoc_files.include('lib/action_mailer/delivery_method/*.rb')
}

spec = eval(File.read('actionmailer.gemspec'))

Rake::GemPackageTask.new(spec) do |p|
  p.gem_spec = spec
end

desc "Release to gemcutter"
task :release => :package do
  require 'rake/gemcutter'
  Rake::Gemcutter::Tasks.new(spec).define
  Rake::Task['gem:push'].invoke
end
