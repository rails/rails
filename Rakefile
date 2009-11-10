require "rubygems"

begin
  require "spec/rake/spectask"
rescue LoadError
  desc "Run specs"
  task(:spec) { $stderr.puts '`gem install rspec` to run specs' }
else
  desc "Run specs using RCov (uses mysql database adapter)"
  Spec::Rake::SpecTask.new(:coverage) do |t|
    t.spec_files =
      ["spec/connections/mysql_connection.rb"] +
      FileList['spec/**/*_spec.rb']

    t.rcov = true
    t.rcov_opts << '--exclude' << "spec,gems"
    t.rcov_opts << '--text-summary'
    t.rcov_opts << '--sort' << 'coverage' << '--sort-reverse'
    t.rcov_opts << '--only-uncovered'
  end

  namespace :spec do
    for adapter in %w[mysql sqlite3 postgresql]
      desc "Run specs with the #{adapter} database adapter"
      Spec::Rake::SpecTask.new(adapter) do |t|
        t.spec_opts = ['--options', "\"#{File.dirname(__FILE__)}/spec/spec.opts\""]
        t.libs << "#{File.dirname(__FILE__)}/vendor/rails/activerecord/lib"
        t.libs << "#{File.dirname(__FILE__)}/spec"
        t.warning = true
        t.spec_files =
          ["spec/connections/#{adapter}_connection.rb"] +
          ["spec/schemas/#{adapter}_schema.rb"] +
          FileList['spec/**/*_spec.rb']
      end
    end
  end

  desc "Run specs with mysql and sqlite3 database adapters (default)"
  task :spec => ["spec:sqlite3", "spec:mysql", "spec:postgresql"]

  desc "Default task is to run specs"
  task :default => :spec
end

desc 'Removes trailing whitespace'
task :whitespace do
  sh %{find . -name '*.rb' -exec sed -i '' 's/ *$//g' {} \\;}
end
