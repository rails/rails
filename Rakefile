require "rubygems"

def gemspec
  @gemspec ||= begin
    gemspec_file = File.expand_path('../arel.gemspec', __FILE__)
    gemspec = eval(File.read(gemspec_file), binding, gemspec_file)
  end
end

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
    %w[mysql sqlite3 postgresql oracle].each do |adapter|
      task "set_env_for_#{adapter}" do
        ENV['ADAPTER'] = adapter
      end

      Spec::Rake::SpecTask.new(adapter) do |t|
        t.spec_opts = ['--options', "\"#{File.dirname(__FILE__)}/spec/spec.opts\""]
        t.libs << "#{File.dirname(__FILE__)}/spec"
        # t.warning = true
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

desc 'Removes trailing whitespace'
task :whitespace do
  sh %{find . -name '*.rb' -exec sed -i '' 's/ *$//g' {} \\;}
end

desc "Build pkg/#{gemspec.full_name}.gem"
task :build => "gemspec:validate" do
  sh %{gem build arel.gemspec}
  FileUtils.mkdir_p "pkg"
  FileUtils.mv gemspec.file_name, "pkg"
end

desc "Install the latest built gem"
task :install => :build do
  sh "gem install --local pkg/#{gemspec.file_name}"
end

namespace :release do
  task :tag do
    release_tag = "v#{gemspec.version}"
    sh "git tag -a #{release_tag} -m 'Tagging #{release_tag}'"
    sh "git push origin #{release_tag}"
  end

  task :gem => :build do
    sh "gem push pkg/#{gemspec.file_name}"
  end
end

desc "Release the current branch to GitHub and Gemcutter"
task :release => %w(release:tag release:gem)

namespace :gemspec do
  desc 'Validate the gemspec'
  task :validate do
    gemspec.validate
  end
end
