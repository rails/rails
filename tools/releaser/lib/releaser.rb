# frozen_string_literal: true

require "json"
require "digest"
require "rake/tasklib"

class Releaser < Rake::TaskLib
  # Order dependent. E.g. Action Mailbox depends on Active Record so it should be after.
  FRAMEWORKS = %w(
    activesupport
    activemodel
    activerecord
    actionview
    actionpack
    activejob
    actionmailer
    actioncable
    activestorage
    actionmailbox
    actiontext
    railties
  )

  attr_reader :root, :version, :tag, :major, :minor, :tiny, :pre

  def initialize(root, version)
    @root = Pathname.new(root)
    @version = version
    @tag = "v#{version}"
    @major, @minor, @tiny, @pre = @version.split(".", 4)
    define
  end

  def define
    directory "#{root}/pkg"

    (FRAMEWORKS + ["rails"]).each do |framework|
      namespace framework do
        task :clean do
          Dir.chdir(root) do
            rm_f gem_path(framework)
          end
        end

        task :update_versions do
          update_versions(framework)
        end

        task gem_path(framework) => [:update_versions, "#{root}/pkg"] do
          dir = if framework == "rails"
            root
          else
            root + framework
          end

          Dir.chdir(dir) do
            sh "gem build #{gemspec(framework)} && mv #{gem_file(framework)} #{root}/pkg/"
          end
        end

        task build: [:clean, gem_path(framework)]
        task install: :build do
          Dir.chdir(root) do
            sh "gem install --pre #{gem_path(framework)}"
          end
        end

        task push: :build do
          Dir.chdir(root) do
            sh "gem push #{gem_path(framework)}#{gem_otp}"

            if File.exist?("#{framework}/package.json")
              Dir.chdir("#{framework}") do
                sh "npm publish --tag #{npm_tag}#{npm_otp}"
              end
            end
          end
        end
      end
    end

    desc "Install gems for all projects."
    task install: FRAMEWORKS.map { |f| "#{f}:install" } + ["rails:install"]

    task :ensure_clean_state do
      if tree_dirty?
        abort "[ABORTING] `git status` reports a dirty tree. Make sure all changes are committed"
      end

      unless ENV["SKIP_TAG"] || inexistent_tag?
        abort "[ABORTING] `git tag` shows that #{tag} already exists. Has this version already\n"\
              "           been released? Git tagging can be skipped by setting SKIP_TAG=1"
      end
    end

    namespace :changelog do
      task :header do
        require "date"

        (FRAMEWORKS + ["guides"]).each do |fw|
          fname = File.join root, fw, "CHANGELOG.md"
          current_contents = File.read(fname)

          header = "## Rails #{version} (#{Date.today.strftime('%B %d, %Y')}) ##\n\n"
          header += "*   No changes.\n\n\n" if current_contents.start_with?("##")
          contents = header + current_contents
          File.write(fname, contents)
        end
      end
    end

    desc "Update version of the frameworks"
    task update_versions: FRAMEWORKS.map { |f| "#{f}:update_versions" } + ["rails:update_versions"]

    desc "Build gem files for all projects"
    task build: FRAMEWORKS.map { |f| "#{f}:build" } + ["rails:build"]

    task checksums: :build do
      Dir.chdir(root) do
        puts
        [*FRAMEWORKS, "rails"].each do |fw|
          path = gem_path(fw)
          sha = ::Digest::SHA256.file(path)
          puts "#{sha}  #{path}"
        end
        puts
      end
    end

    task :bundle do
      sh "bundle check"
    end

    desc "Prepare the release"
    task prep_release: %w(ensure_clean_state changelog:header build bundle)

    task :check_gh_client do
      sh "gh auth status" do |ok, res|
        unless ok
          raise "GitHub CLI is not logged in. Please run `gh auth login` to log in."
        end
      end
      default_repo = `git config --local --get-regexp '\.gh-resolved$'`.strip
      if !$?.success? || default_repo.empty?
        raise "GitHub CLI does not have a default repo configured. Please run `gh repo set-default rails/rails`"
      end
    end

    task :commit do
      Dir.chdir(root) do
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
    end

    task :tag do
      sh "git push"
      sh "git tag -s -m '#{tag} release' #{tag}"
      sh "git push --tags"
    end

    desc "Create GitHub release"
    task create_release: :check_gh_client do
      Dir.chdir(root) do
        File.write("pkg/#{version}.md", release_notes)

        sh "gh release create --verify-tag #{tag} -t #{version} -F pkg/#{version}.md --draft#{pre_release? ? " --prerelease" : ""}"
      end
    end

    desc "Release all gems and create a tag"
    task release: %w(check_gh_client prep_release commit tag create_release)

    task pre_push: [:build, :checksums]

    desc "Push the gem to rubygems.org and the npm package to npmjs.com"
    task push: [:pre_push] + FRAMEWORKS.map { |f| "#{f}:push" } + ["rails:push"]
  end

  def pre_release?
    @pre_release ||= pre && pre.match?(/rc|beta|alpha/)
  end

  def npm_tag
    pre_release? ? "pre" : "latest"
  end

  # This "npm-ifies" the current version number
  # With npm, versions such as "5.0.0.rc1" or "5.0.0.beta1.1" are not compliant with its
  # versioning system, so they must be transformed to "5.0.0-rc1" and "5.0.0-beta1-1" respectively.
  # "5.0.0"     --> "5.0.0"
  # "5.0.1"     --> "5.0.100"
  # "5.0.0.1"   --> "5.0.1"
  # "5.0.1.1"   --> "5.0.101"
  # "5.0.0.rc1" --> "5.0.0-rc1"
  # "5.0.0.beta1.1" --> "5.0.0-beta1-1"
  def npm_version
    @npm_version ||= begin
      if pre_release?
        pre_release = pre.tr(".", "-")
        npm_pre = 0
      else
        npm_pre = pre.to_i
        pre_release = nil
      end

      "#{major}.#{minor}.#{(tiny.to_i * 100) + npm_pre}#{pre_release ? "-#{pre_release}" : ""}"
    end
  end

  def gem_path(framework)
    "pkg/#{gem_file(framework)}"
  end

  def gem_file(framework)
    "#{framework}-#{version}.gem"
  end

  def gemspec(framework)
    "#{framework}.gemspec"
  end

  def update_versions(framework)
    return if framework == "rails"

    Dir.chdir(root) do
      glob = "#{framework}/lib/*/gem_version.rb"

      file = Dir[glob].first
      ruby = File.read(file)

      ruby.gsub!(/^(\s*)MAJOR(\s*)= .*?$/, "\\1MAJOR = #{major}")
      raise "Could not insert MAJOR in #{file}" unless $1

      ruby.gsub!(/^(\s*)MINOR(\s*)= .*?$/, "\\1MINOR = #{minor}")
      raise "Could not insert MINOR in #{file}" unless $1

      ruby.gsub!(/^(\s*)TINY(\s*)= .*?$/, "\\1TINY  = #{tiny}")
      raise "Could not insert TINY in #{file}" unless $1

      ruby.gsub!(/^(\s*)PRE(\s*)= .*?$/, "\\1PRE   = #{pre.inspect}")
      raise "Could not insert PRE in #{file}" unless $1

      File.open(file, "w") { |f| f.write ruby }

      package_json = "#{framework}/package.json"

      if File.exist?(package_json) && JSON.parse(File.read(package_json))["version"] != npm_version
        Dir.chdir("#{framework}") do
          if sh("which npm > /dev/null 2>&1", verbose: false)
            sh "npm version #{npm_version} --no-git-tag-version > /dev/null 2>&1", verbose: false
          else
            raise "You must have npm installed to release Rails."
          end
        end
      end
    end
  end

  def release_notes
    release_notes = +""

    (FRAMEWORKS + ["guides"]).each do |framework|
      release_notes << "## #{framework_name(framework)}\n"
      file_name = File.join root, framework, "CHANGELOG.md"
      contents = File.readlines file_name
      contents.shift # Remove the header
      changes = []

      until end_of_notes?(contents) || contents.empty?
        changes << contents.shift
      end

      release_notes << changes.join
    end

    release_notes
  end

  def framework_name(framework)
    framework.split(/(?<=active|action)/).map(&:capitalize).join(" ")
  end

  private
    FILES_TO_IGNORE = %w(
      RAILS_VERSION
      CHANGELOG
      Gemfile.lock
      package.json
      gem_version.rb
      tasks/release.rb
      releaser.rb
      yarn.lock
    )
    def tree_dirty?
      !`git status -s | grep -v '#{FILES_TO_IGNORE.join("\\|")}'`.strip.empty?
    end

    def inexistent_tag?
      `git tag | grep '^#{tag}$'`.strip.empty?
    end

    def npm_otp
      " --otp " + ykman("npmjs.com")
    rescue
      " --provenance --access public"
    end

    def gem_otp
      " --otp " + ykman("rubygems.org")
    rescue
      ""
    end

    def ykman(service)
      `ykman oath accounts code -s #{service}`.chomp
    end

    def end_of_notes?(contents)
      line = contents.first

      line =~ /^## Rails \d+\.\d+\.\d+.*$/ ||
        line =~ /^Please check.*for previous changes\.$/ ||
        contents.empty?
    end
end
