FRAMEWORKS = %w( activesupport activemodel activerecord actionview actionpack activejob actionmailer actioncable railties )

root    = File.expand_path('../../', __FILE__)
version = File.read("#{root}/RAILS_VERSION").strip
tag     = "v#{version}"

directory "pkg"

(FRAMEWORKS + ['rails']).each do |framework|
  namespace framework do
    gem     = "pkg/#{framework}-#{version}.gem"
    gemspec = "#{framework}.gemspec"

    task :clean do
      rm_f gem
    end

    task :update_versions do
      glob = root.dup
      if framework == "rails"
        glob << "/version.rb"
      else
        glob << "/#{framework}/lib/*"
        glob << "/gem_version.rb"
      end

      file = Dir[glob].first
      ruby = File.read(file)

      major, minor, tiny, pre = version.split('.', 4)
      pre = pre ? pre.inspect : "nil"

      ruby.gsub!(/^(\s*)MAJOR(\s*)= .*?$/, "\\1MAJOR = #{major}")
      raise "Could not insert MAJOR in #{file}" unless $1

      ruby.gsub!(/^(\s*)MINOR(\s*)= .*?$/, "\\1MINOR = #{minor}")
      raise "Could not insert MINOR in #{file}" unless $1

      ruby.gsub!(/^(\s*)TINY(\s*)= .*?$/, "\\1TINY  = #{tiny}")
      raise "Could not insert TINY in #{file}" unless $1

      ruby.gsub!(/^(\s*)PRE(\s*)= .*?$/, "\\1PRE   = #{pre}")
      raise "Could not insert PRE in #{file}" unless $1

      File.open(file, 'w') { |f| f.write ruby }
    end

    task gem => %w(update_versions pkg) do
      cmd = ""
      cmd << "cd #{framework} && " unless framework == "rails"
      cmd << "bundle exec rake package && " unless framework == "rails"
      cmd << "gem build #{gemspec} && mv #{framework}-#{version}.gem #{root}/pkg/"
      sh cmd
    end

    task :build => [:clean, gem]
    task :install => :build do
      sh "gem install --pre #{gem}"
    end

    task :push => :build do
      sh "gem push #{gem}"

      # When running the release task we usually run build first to check that the gem works properly.
      # NPM will refuse to publish or rebuild the gem if the version is changed when the Rails gem
      # versions are changed. This then causes the gem push to fail. Because of this we need to update
      # the version and publish at the same time.
      if File.exist?("#{framework}/package.json")
        Dir.chdir("#{framework}") do
          # This "npm-ifies" the current version
          # With npm, versions such as "5.0.0.rc1" or "5.0.0.beta1.1" are not compliant with its
          # versioning system, so they must be transformed to "5.0.0-rc1" and "5.0.0-beta1-1" respectively.

          # In essence, the code below runs through all "."s that appear in the version,
          # and checks to see if their index in the version string is greater than or equal to 2,
          # and if so, it will change the "." to a "-".

          # Sample version transformations:
          # irb(main):001:0> version = "5.0.1.1"
          # => "5.0.1.1"
          # irb(main):002:0> version.gsub(/\./).with_index { |s, i| i >= 2 ? '-' : s }
          # => "5.0.1-1"
          # irb(main):003:0> version = "5.0.0.rc1"
          # => "5.0.0.rc1"
          # irb(main):004:0> version.gsub(/\./).with_index { |s, i| i >= 2 ? '-' : s }
          # => "5.0.0-rc1"
          version = version.gsub(/\./).with_index { |s, i| i >= 2 ? '-' : s }

          # Check if npm is installed, and raise an error if not
          if sh 'which npm'
            sh "npm version #{version} --no-git-tag-version"
            sh "npm publish"
          else
            raise 'You must have npm installed to release Rails.'
          end
        end
      end
    end
  end
end

namespace :changelog do
  task :header do
    (FRAMEWORKS + ['guides']).each do |fw|
      require 'date'
      fname = File.join fw, 'CHANGELOG.md'

      header = "## Rails #{version} (#{Date.today.strftime('%B %d, %Y')}) ##\n\n*   No changes.\n\n\n"
      contents = header + File.read(fname)
      File.open(fname, 'wb') { |f| f.write contents }
    end
  end

  task :release_date do
    (FRAMEWORKS + ['guides']).each do |fw|
      require 'date'
      replace = "## Rails #{version} (#{Date.today.strftime('%B %d, %Y')}) ##\n"
      fname = File.join fw, 'CHANGELOG.md'

      contents = File.read(fname).sub(/^(## Rails .*)\n/, replace)
      File.open(fname, 'wb') { |f| f.write contents }
    end
  end

  task :release_summary do
    (FRAMEWORKS + ['guides']).each do |fw|
      puts "## #{fw}"
      fname    = File.join fw, 'CHANGELOG.md'
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
  task :build           => FRAMEWORKS.map { |f| "#{f}:build"           } + ['rails:build']
  task :update_versions => FRAMEWORKS.map { |f| "#{f}:update_versions" } + ['rails:update_versions']
  task :install         => FRAMEWORKS.map { |f| "#{f}:install"         } + ['rails:install']
  task :push            => FRAMEWORKS.map { |f| "#{f}:push"            } + ['rails:push']

  task :ensure_clean_state do
    unless `git status -s | grep -v 'RAILS_VERSION\\|CHANGELOG\\|Gemfile.lock'`.strip.empty?
      abort "[ABORTING] `git status` reports a dirty tree. Make sure all changes are committed"
    end

    unless ENV['SKIP_TAG'] || `git tag | grep '^#{tag}$'`.strip.empty?
      abort "[ABORTING] `git tag` shows that #{tag} already exists. Has this version already\n"\
            "           been released? Git tagging can be skipped by setting SKIP_TAG=1"
    end
  end

  task :bundle do
    sh 'bundle check'
  end

  task :commit do
    File.open('pkg/commit_message.txt', 'w') do |f|
      f.puts "# Preparing for #{version} release\n"
      f.puts
      f.puts "# UNCOMMENT THE LINE ABOVE TO APPROVE THIS COMMIT"
    end

    sh "git add . && git commit --verbose --template=pkg/commit_message.txt"
    rm_f "pkg/commit_message.txt"
  end

  task :tag do
    sh "git tag -s -m '#{tag} release' #{tag}"
    sh "git push --tags"
  end

  task :prep_release => %w(ensure_clean_state build)

  task :release => %w(ensure_clean_state build bundle commit tag push)
end
