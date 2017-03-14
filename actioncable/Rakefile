require "rake/testtask"
require "pathname"
require "open3"
require "action_cable"

dir = File.dirname(__FILE__)

task default: :test

task package: %w( assets:compile assets:verify )

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = Dir.glob("#{dir}/test/**/*_test.rb")
  t.warning = true
  t.verbose = true
  t.ruby_opts = ["--dev"] if defined?(JRUBY_VERSION)
end

namespace :test do
  task :isolated do
    Dir.glob("test/**/*_test.rb").all? do |file|
      sh(Gem.ruby, "-w", "-Ilib:test", file)
    end || raise("Failures")
  end

  task :integration do
    require "blade"
    if ENV["CI"]
      Blade.start(interface: :ci)
    else
      Blade.start(interface: :runner)
    end
  end
end

namespace :assets do
  desc "Compile Action Cable assets"
  task :compile do
    require "blade"
    require "sprockets"
    require "sprockets/export"
    Blade.build
  end

  desc "Verify compiled Action Cable assets"
  task :verify do
    file = "lib/assets/compiled/action_cable.js"
    pathname = Pathname.new("#{dir}/#{file}")

    print "[verify] #{file} exists "
    if pathname.exist?
      puts "[OK]"
    else
      $stderr.puts "[FAIL]"
      fail
    end

    print "[verify] #{file} is a UMD module "
    if pathname.read =~ /module\.exports.*define\.amd/m
      puts "[OK]"
    else
      $stderr.puts "[FAIL]"
      fail
    end

    print "[verify] #{dir} can be required as a module "
    stdout, stderr, status = Open3.capture3("node", "--print", "window = {}; require('#{dir}');")
    if status.success?
      puts "[OK]"
    else
      $stderr.puts "[FAIL]\n#{stderr}"
      fail
    end
  end
end
