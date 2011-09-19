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
    
      ver_parts = Hash.new
      ver_parts[:MAJOR], ver_parts[:MINOR], ver_parts[:TINY], ver_parts[:PRE] = version.split('.')
      ver_parts[:PRE] = ver_parts[:PRE] ? ver_parts[:PRE].inspect : "nil"
      
      ver_parts.each do |ver_name, ver_value|
        ruby.gsub! /^(\s*)#{ver_name}(\s+)= .*?$/, "\\1#{ver_name}\\2= #{ver_value}"
        raise "Could not insert #{ver_name} in #{file}" unless $1
      end

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

namespace :changelog do
  task :release_date do
    FRAMEWORKS.each do |fw|
      require 'date'
      replace = '\1(' + Date.today.strftime('%B %d, %Y') + ')'
      fname = File.join fw, 'CHANGELOG'

      contents = File.read(fname).sub(/^([^(]*)\(unreleased\)/, replace)
      File.open(fname, 'wb') { |f| f.write contents }
    end
  end

  task :release_summary do
    FRAMEWORKS.each do |fw|
      puts "## #{fw}"
      fname    = File.join fw, 'CHANGELOG'
      contents = File.readlines fname
      contents.shift
      changes = []
      changes << contents.shift until contents.first =~ /^\*Rails \d+\.\d+\.\d+/
      puts changes.reject { |change| change.strip.empty? }.join
      puts
    end
  end
end

namespace :all do
  task :build   => FRAMEWORKS.map { |f| "#{f}:build"   } + ['rails:build']
  task :install => FRAMEWORKS.map { |f| "#{f}:install" } + ['rails:install']
  task :push    => FRAMEWORKS.map { |f| "#{f}:push"    } + ['rails:push']

  task :ensure_clean_state do
    unless `git status -s | grep -v RAILS_VERSION`.strip.empty?
      abort "[ABORTING] `git status` reports a dirty tree. Make sure all changes are committed"
    end

    unless ENV['SKIP_TAG'] || `git tag | grep #{tag}`.strip.empty?
      abort "[ABORTING] `git tag` shows that #{tag} already exists. Has this version already\n"\
            "           been released? Git tagging can be skipped by setting SKIP_TAG=1"
    end
  end

  task :commit do
    File.open('dist/commit_message.txt', 'w') do |f|
      f.puts "# Preparing for #{version} release\n"
      f.puts
      f.puts "# UNCOMMENT THE LINE ABOVE TO APPROVE THIS COMMIT"
    end

    sh "git add . && git commit --verbose --template=dist/commit_message.txt"
    rm_f "dist/commit_message.txt"
  end

  task :tag do
    sh "git tag #{tag}"
  end

  task :release => %w(ensure_clean_state build commit tag push)
end
