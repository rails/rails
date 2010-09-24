require "rubygems"

begin
  require "spec/rake/spectask"
rescue LoadError
  desc "Run specs"
  task(:spec) { $stderr.puts '`gem install rspec` to run specs' }
else
  namespace :spec do
    %w[mysql sqlite3 postgresql oracle].each do |adapter|
      task "set_env_for_#{adapter}" do
        ENV['ADAPTER'] = adapter
      end

      Spec::Rake::SpecTask.new(adapter) do |t|
        t.spec_opts = ['--options', "\"#{File.dirname(__FILE__)}/spec/spec.opts\""]
        t.libs << "#{File.dirname(__FILE__)}/spec"
        t.warning = true
        t.spec_files = FileList['spec/**/*_spec.rb']
      end

      desc "Run specs with the #{adapter} database adapter"
      task adapter => "set_env_for_#{adapter}"
    end
  end

  desc "Run specs with mysql and sqlite3 database adapters (default)"
  task :spec => ["spec:sqlite3", "spec:mysql", "spec:postgresql"]

  desc "Default task is to run specs"
  task :default => :spec
end
