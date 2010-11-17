FRAMEWORKS = %w( activesupport activemodel activerecord activeresource actionpack actionmailer railties )

root    = File.expand_path('../../', __FILE__)
version = File.read("#{root}/RAILS_VERSION").strip
tag     = "v#{version}"

directory "dist"

(FRAMEWORKS + ['rails']).each do |framework|
  namespace framework do
    gem     = "dist/#{framework}-#{version}.gem"
    gemspec = "#{framework}.gemspec"

    task :clean do
      rm_f gem
    end

    task :update_version_rb do
      glob = root.dup
      glob << "/#{framework}/lib/*" unless framework == "rails"
      glob << "/version.rb"

      file = Dir[glob].first
      ruby = File.read(file)

      major, minor, tiny, pre = version.split('.')
      pre ||= "nil"

      ruby.gsub! /^(\s*)MAJOR = .*?$/, "\\1MAJOR = #{major}"
      raise "Could not insert MAJOR in #{file}" unless $1

      ruby.gsub! /^(\s*)MINOR = .*?$/, "\\1MINOR = #{minor}"
      raise "Could not insert MINOR in #{file}" unless $1

      ruby.gsub! /^(\s*)TINY  = .*?$/, "\\1TINY  = #{tiny}"
      raise "Could not insert TINY in #{file}" unless $1

      ruby.gsub! /^(\s*)PRE   = .*?$/, "\\1PRE   = #{pre}"
      raise "Could not insert PRE in #{file}" unless $1

      File.open(file, 'w') { |f| f.write ruby }
    end

    task gem => %w(update_version_rb dist) do
      cmd = ""
      cmd << "cd #{framework} && " unless framework == "rails"
      cmd << "gem build #{gemspec} && mv #{framework}-#{version}.gem #{root}/dist/"
      sh cmd
    end

    task :build => [:clean, gem]
    task :install => :build do
      sh "gem install #{gem}"
    end

    task :prep_release => [:ensure_clean_state, :build]

    task :push => :build do
      sh "gem push #{gem}"
    end
  end
end

namespace :release do
  task :ensure_clean_state do
    unless `git status -s | grep -v RAILS_VERSION`.strip.empty?
      abort "[ABORTING] `git status` reports a dirty tree. Make sure all changes are committed"
    end

    unless ENV['SKIP_TAG'] || `git tag | grep #{tag}`.strip.empty?
      abort "[ABORTING] `git tag` shows that #{tag} already exists. Has this version already\n"\
            "           been released? Git tagging can be skipped by setting SKIP_TAG=1"
    end
  end

  task :tag do
    sh "git tag #{tag}"
  end
end

namespace :all do
  task :build   => FRAMEWORKS.map { |f| "#{f}:build"   } + ['rails:build']
  task :install => FRAMEWORKS.map { |f| "#{f}:install" } + ['rails:install']
  task :push    => FRAMEWORKS.map { |f| "#{f}:push"    } + ['rails:push']
end
