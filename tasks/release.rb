FRAMEWORKS = %w( activesupport activemodel activerecord actionview actionpack activejob actionmailer actioncable railties )

root    = File.expand_path("../../", __FILE__)
version = File.read("#{root}/RAILS_VERSION").strip
tag     = "v#{version}"

directory "pkg"

# This "npm-ifies" the current version number
# With npm, versions such as "5.0.0.rc1" or "5.0.0.beta1.1" are not compliant with its
# versioning system, so they must be transformed to "5.0.0-rc1" and "5.0.0-beta1-1" respectively.

# "5.0.1"     --> "5.0.1"
# "5.0.1.1"   --> "5.0.1-1" *
# "5.0.0.rc1" --> "5.0.0-rc1"
#
# * This makes it a prerelease. That's bad, but we haven't come up with
# a better solution at the moment.
npm_version = version.gsub(/\./).with_index { |s, i| i >= 2 ? "-" : s }

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

      major, minor, tiny, pre = version.split(".", 4)
      pre = pre ? pre.inspect : "nil"

      ruby.gsub!(/^(\s*)MAJOR(\s*)= .*?$/, "\\1MAJOR = #{major}")
      raise "Could not insert MAJOR in #{file}" unless $1

      ruby.gsub!(/^(\s*)MINOR(\s*)= .*?$/, "\\1MINOR = #{minor}")
      raise "Could not insert MINOR in #{file}" unless $1

      ruby.gsub!(/^(\s*)TINY(\s*)= .*?$/, "\\1TINY  = #{tiny}")
      raise "Could not insert TINY in #{file}" unless $1

      ruby.gsub!(/^(\s*)PRE(\s*)= .*?$/, "\\1PRE   = #{pre}")
      raise "Could not insert PRE in #{file}" unless $1

      File.open(file, "w") { |f| f.write ruby }

      require "json"
      if File.exist?("#{framework}/package.json") && JSON.parse(File.read("#{framework}/package.json"))["version"] != npm_version
        Dir.chdir("#{framework}") do
          if sh "which npm"
            sh "npm version #{npm_version} --no-git-tag-version"
          else
            raise "You must have npm installed to release Rails."
          end
        end
      end
    end

    task gem => %w(update_versions pkg) do
      cmd = ""
      cmd << "cd #{framework} && " unless framework == "rails"
      cmd << "bundle exec rake package && " unless framework == "rails"
      cmd << "gem build #{gemspec} && mv #{framework}-#{version}.gem #{root}/pkg/"
      sh cmd
    end

    task build: [:clean, gem]
    task install: :build do
      sh "gem install --pre #{gem}"
    end

    task push: :build do
      sh "gem push #{gem}"

      if File.exist?("#{framework}/package.json")
        Dir.chdir("#{framework}") do
          npm_tag = version =~ /[a-z]/ ? "pre" : "latest"
          sh "npm publish --tag #{npm_tag}"
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
      current_contents = File.read(fname)

      header = "## Rails #{version} (#{Date.today.strftime('%B %d, %Y')}) ##\n\n"
      header << "*   No changes.\n\n\n" if current_contents =~ /\A##/
      contents = header + current_contents
      File.open(fname, 'wb') { |f| f.write contents }
    end
  end

  task :release_date do
    (FRAMEWORKS + ["guides"]).each do |fw|
      require "date"
      replace = "## Rails #{version} (#{Date.today.strftime('%B %d, %Y')}) ##\n"
      fname = File.join fw, "CHANGELOG.md"

      contents = File.read(fname).sub(/^(## Rails .*)\n/, replace)
      File.open(fname, "wb") { |f| f.write contents }
    end
  end

  task :release_summary do
    (FRAMEWORKS + ["guides"]).each do |fw|
      puts "## #{fw}"
      fname    = File.join fw, "CHANGELOG.md"
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
  task build: FRAMEWORKS.map { |f| "#{f}:build"           } + ["rails:build"]
  task update_versions: FRAMEWORKS.map { |f| "#{f}:update_versions" } + ["rails:update_versions"]
  task install: FRAMEWORKS.map { |f| "#{f}:install"         } + ["rails:install"]
  task push: FRAMEWORKS.map { |f| "#{f}:push"            } + ["rails:push"]

  task :ensure_clean_state do
    unless `git status -s | grep -v 'RAILS_VERSION\\|CHANGELOG\\|Gemfile.lock\\|package.json\\|version.rb'`.strip.empty?
      abort "[ABORTING] `git status` reports a dirty tree. Make sure all changes are committed"
    end

    unless ENV["SKIP_TAG"] || `git tag | grep '^#{tag}$'`.strip.empty?
      abort "[ABORTING] `git tag` shows that #{tag} already exists. Has this version already\n"\
            "           been released? Git tagging can be skipped by setting SKIP_TAG=1"
    end
  end

  task :bundle do
    sh "bundle check"
  end

  task :commit do
    unless `git status -s`.strip.empty?
      File.open('pkg/commit_message.txt', 'w') do |f|
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
