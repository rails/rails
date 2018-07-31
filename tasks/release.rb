# frozen_string_literal: true

FRAMEWORKS = %w( activesupport activemodel activerecord actionview actionpack activejob actionmailer actioncable activestorage railties )
FRAMEWORK_NAMES = Hash.new { |h, k| k.split(/(?<=active|action)/).map(&:capitalize).join(" ") }

root    = File.expand_path("..", __dir__)
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

(FRAMEWORKS + ["rails"]).each do |framework|
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
      cmd += "cd #{framework} && " unless framework == "rails"
      cmd += "bundle exec rake package && " unless framework == "rails"
      cmd += "gem build #{gemspec} && mv #{framework}-#{version}.gem #{root}/pkg/"
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
          npm_tag = /[a-z]/.match?(version) ? "pre" : "latest"
          sh "npm publish --tag #{npm_tag}"
        end
      end
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
      header += "*   No changes.\n\n\n" if current_contents =~ /\A##/
      contents = header + current_contents
      File.write(fname, contents)
    end
  end

  task :release_date do
    (FRAMEWORKS + ["guides"]).each do |fw|
      require "date"
      replace = "## Rails #{version} (#{Date.today.strftime('%B %d, %Y')}) ##\n"
      fname = File.join fw, "CHANGELOG.md"

      contents = File.read(fname).sub(/^(## Rails .*)\n/, replace)
      File.write(fname, contents)
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
    unless `git status -s | grep -v 'RAILS_VERSION\\|CHANGELOG\\|Gemfile.lock\\|package.json\\|version.rb\\|tasks/release.rb'`.strip.empty?
      abort "[ABORTING] `git status` reports a dirty tree. Make sure all changes are committed"
    end

    unless ENV["SKIP_TAG"] || `git tag | grep '^#{tag}$'`.strip.empty?
      abort "[ABORTING] `git tag` shows that #{tag} already exists. Has this version already\n"\
            "           been released? Git tagging can be skipped by setting SKIP_TAG=1"
    end
  end

  task verify: :install do
    app_name = "pkg/verify-#{version}-#{Time.now.to_i}"
    sh "rails _#{version}_ new #{app_name} --skip-bundle" # Generate with the right version.
    cd app_name

    # Replace the generated gemfile entry with the exact version.
    File.write("Gemfile", File.read("Gemfile").sub(/^gem 'rails.*/, "gem 'rails', '#{version}'"))
    sh "bundle"

    sh "rails generate scaffold user name admin:boolean && rails db:migrate"

    puts "Booting a Rails server. Verify the release by:"
    puts
    puts "- Seeing the correct release number on the root page"
    puts "- Viewing /users"
    puts "- Creating a user"
    puts "- Updating a user (e.g. disable the admin flag)"
    puts "- Deleting a user on /users"
    puts "- Whatever else you want."
    begin
      sh "rails server"
    rescue Interrupt
      # Server passes along interrupt. Prevent halting verify task.
    end
  end

  task :bundle do
    sh "bundle check"
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

  task prep_release: %w(ensure_clean_state build bundle commit)

  task release: %w(prep_release tag push)
end

module Announcement
  class Version
    def initialize(version)
      @version, @gem_version = version, Gem::Version.new(version)
    end

    def to_s
      @version
    end

    def previous
      @gem_version.segments[0, 3].tap { |v| v[2] -= 1 }.join(".")
    end

    def major_or_security?
      @gem_version.segments[2].zero? || @gem_version.segments[3].is_a?(Integer)
    end

    def rc?
      @version =~ /rc/
    end
  end
end

task :announce do
  Dir.chdir("pkg/") do
    versions = ENV["VERSIONS"] ? ENV["VERSIONS"].split(",") : [ version ]
    versions = versions.sort.map { |v| Announcement::Version.new(v) }

    raise "Only valid for patch releases" if versions.any?(&:major_or_security?)

    if versions.any?(&:rc?)
      require "date"
      future_date = Date.today + 5
      future_date += 1 while future_date.saturday? || future_date.sunday?

      github_user = `git config github.user`.chomp
    end

    require "erb"
    template = File.read("../tasks/release_announcement_draft.erb")

    match = ERB.version.match(/\Aerb\.rb \[(?<version>[^ ]+) /)
    if match && match[:version] >= "2.2.0" # Ruby 2.6+
      puts ERB.new(template, trim_mode: "<>").result(binding)
    else
      puts ERB.new(template, nil, "<>").result(binding)
    end
  end
end
