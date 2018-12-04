FRAMEWORKS = %w( activesupport activemodel activerecord actionview actionpack activejob actionmailer railties )
FRAMEWORK_NAMES = Hash.new { |h, k| k.split(/(?<=active|action)/).map(&:capitalize).join(" ") }

root    = File.expand_path('../../', __FILE__)
version = File.read("#{root}/RAILS_VERSION").strip
tag     = "v#{version}"
gem_version = Gem::Version.new(version)

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

      major, minor, tiny, pre = version.split('.')
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
      cmd << "gem build #{gemspec} && mv #{framework}-#{version}.gem #{root}/pkg/"
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
  task :header do
    (FRAMEWORKS + ["guides"]).each do |fw|
      require "date"
      fname = File.join fw, "CHANGELOG.md"
      current_contents = File.read(fname)

      header = "## Rails #{version} (#{Date.today.strftime('%B %d, %Y')}) ##\n\n"
      header << "*   No changes.\n\n\n" if current_contents =~ /\A##/
      contents = header + current_contents
      File.open(fname, "wb") { |f| f.write contents }
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

  task :release_summary, [:base_release] do |_, args|
    release_regexp = args[:base_release] ? Regexp.escape(args[:base_release]) : /\d+\.\d+\.\d+/

    FRAMEWORKS.each do |fw|
      puts "## #{FRAMEWORK_NAMES[fw]}"
      fname    = File.join fw, "CHANGELOG.md"
      contents = File.readlines fname
      contents.shift
      changes = []
      until contents.first =~ /^## Rails #{release_regexp}.*$/
        changes << contents.shift
      end

      puts changes.join
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
    unless `git status -s | grep -v 'RAILS_VERSION\\|CHANGELOG\\|Gemfile.lock\\|version.rb'`.strip.empty?
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
    unless `git status -s`.strip.empty?
      File.open("pkg/commit_message.txt", "w") do |f|
        f.puts "# Preparing for #{version} release\n"
        f.puts
        f.puts "# UNCOMMENT THE LINE ABOVE TO APPROVE THIS COMMIT"
      end

      sh "git add . && git commit --verbose --template=pkg/commit_message.txt"
      rm_f "pkg/commit_message.txt"
    end
  end

  task :tag do
    sh "git tag -s -m '#{tag} release' #{tag}"
    sh "git push --tags"
  end

  task :prep_release => %w(ensure_clean_state build bundle commit)

  task :release => %w(prep_release tag push)
end

task :announce do
  Dir.chdir("pkg/") do
    if gem_version.segments[2] == 0 || gem_version.segments[3].is_a?(Integer)
      # Not major releases, and not security releases
      raise "Only valid for patch releases"
    end

    sums = "$ shasum -a 256 *-#{version}.gem\n" + `shasum -a 256 *-#{version}.gem`

    puts "Hi everyone,"
    puts

    puts "I am happy to announce that Rails #{version} has been released."
    puts

    previous_version = gem_version.segments[0, 3]
    previous_version[2] -= 1
    previous_version = previous_version.join(".")

    if version =~ /rc/
      require "date"
      future_date = Date.today + 5
      future_date += 1 while future_date.saturday? || future_date.sunday?

      github_user = `git config github.user`.chomp

      puts <<MSG
If no regressions are found, expect the final release on #{future_date.strftime('%A, %B %-d, %Y')}.
If you find one, please open an [issue on GitHub](https://github.com/rails/rails/issues/new)
#{"and mention me (@#{github_user}) on it, " unless github_user.empty?}so that we can fix it before the final release.

MSG
    end

    puts <<MSG
## CHANGES since #{previous_version}

To view the changes for each gem, please read the changelogs on GitHub:

MSG
    FRAMEWORKS.sort.each do |framework|
      puts "* [#{FRAMEWORK_NAMES[framework]} CHANGELOG](https://github.com/rails/rails/blob/v#{version}/#{framework}/CHANGELOG.md)"
    end
    puts <<MSG

*Full listing*

To see the full list of changes, [check out all the commits on
GitHub](https://github.com/rails/rails/compare/v#{previous_version}...v#{version}).

## SHA-256

If you'd like to verify that your gem is the same as the one I've uploaded,
please use these SHA-256 hashes.

Here are the checksums for #{version}:

```
#{sums}
```

As always, huge thanks to the many contributors who helped with this release.

MSG
  end
end
