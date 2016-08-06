require "rake/testtask"

desc "Default Task"
task default: [ :test ]

task :package

# Run the unit tests
Rake::TestTask.new { |t|
  t.libs << "test"
  t.pattern = "test/**/*_test.rb"
  t.warning = true
  t.verbose = true
  t.ruby_opts = ["--dev"] if defined?(JRUBY_VERSION)
}

namespace :test do
  task :isolated do
    Dir.glob("test/**/*_test.rb").all? do |file|
      sh(Gem.ruby, "-w", "-Ilib:test", file)
    end or raise "Failures"
  end
end
