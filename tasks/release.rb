# frozen_string_literal: true

require_relative "../tools/releaser/lib/releaser"

FRAMEWORK_NAMES = Hash.new { |h, k| k.split(/(?<=active|action)/).map(&:capitalize).join(" ") }

root    = File.expand_path("..", __dir__)
version = File.read("#{root}/RAILS_VERSION").strip
releaser = Releaser.new(root, version)

directory "pkg"

(Releaser::FRAMEWORKS + ["rails"]).each do |framework|
  namespace framework do
    task :clean do
      rm_f releaser.gem_path(framework)
    end

    task :update_versions do
      releaser.update_versions(framework)
    end

    task releaser.gem_path(framework) => %w(update_versions pkg) do
      cmd = ""
      cmd += "cd #{framework} && " unless framework == "rails"
      cmd += "gem build #{releaser.gemspec(framework)} && mv #{releaser.gem_file(framework)} #{root}/pkg/"
      sh cmd
    end

    task build: [:clean, releaser.gem_path(framework)]
    task install: :build do
      sh "gem install --pre #{releaser.gem_path(framework)}"
    end

    task push: :build do
      sh "gem push #{releaser.gem_path(framework)}#{releaser.gem_otp}"

      if File.exist?("#{framework}/package.json")
        Dir.chdir("#{framework}") do
          sh "npm publish --tag #{releaser.npm_tag}#{releaser.npm_otp}"
        end
      end
    end
  end
end

namespace :changelog do
  task :header do
    (Releaser::FRAMEWORKS + ["guides"]).each do |fw|
      require "date"
      fname = File.join fw, "CHANGELOG.md"
      current_contents = File.read(fname)

      header = "## Rails #{releaser.version} (#{Date.today.strftime('%B %d, %Y')}) ##\n\n"
      header += "*   No changes.\n\n\n" if current_contents.start_with?("##")
      contents = header + current_contents
      File.write(fname, contents)
    end
  end

  task :release_date do
    (Releaser::FRAMEWORKS + ["guides"]).each do |fw|
      require "date"
      replace = "## Rails #{releaser.version} (#{Date.today.strftime('%B %d, %Y')}) ##\n"
      fname = File.join fw, "CHANGELOG.md"

      contents = File.read(fname).sub(/^(## Rails .*)\n/, replace)
      File.write(fname, contents)
    end
  end

  task :release_summary, [:base_release, :release] do |_, args|
    release_regexp = args[:base_release] ? Regexp.escape(args[:base_release]) : /\d+\.\d+\.\d+/

    puts args[:release]

    Releaser::FRAMEWORKS.each do |fw|
      puts "## #{FRAMEWORK_NAMES[fw]}"
      fname    = File.join fw, "CHANGELOG.md"
      contents = File.readlines fname
      contents.shift
      changes = []
      until contents.first =~ /^## Rails #{release_regexp}.*$/ ||
          contents.first =~ /^Please check.*for previous changes\.$/ ||
          contents.empty?
        changes << contents.shift
      end

      puts changes.join
      puts
    end
  end
end

namespace :all do
  task build: Releaser::FRAMEWORKS.map { |f| "#{f}:build"           } + ["rails:build"]
  task update_versions: Releaser::FRAMEWORKS.map { |f| "#{f}:update_versions" } + ["rails:update_versions"]
  task install: Releaser::FRAMEWORKS.map { |f| "#{f}:install"         } + ["rails:install"]
  task push: Releaser::FRAMEWORKS.map { |f| "#{f}:push"            } + ["rails:push"]

  task :ensure_clean_state do
    unless `git status -s | grep -v 'RAILS_VERSION\\|CHANGELOG\\|Gemfile.lock\\|package.json\\|gem_version.rb\\|tasks/release.rb'`.strip.empty?
      abort "[ABORTING] `git status` reports a dirty tree. Make sure all changes are committed"
    end

    unless ENV["SKIP_TAG"] || `git tag | grep '^#{releaser.tag}$'`.strip.empty?
      abort "[ABORTING] `git tag` shows that #{releaser.tag} already exists. Has this version already\n"\
            "           been released? Git tagging can be skipped by setting SKIP_TAG=1"
    end
  end

  task verify: :install do
    require "tmpdir"

    cd Dir.tmpdir
    app_name = "verify-#{releaser.version}-#{Time.now.to_i}"
    sh "rails _#{releaser.version}_ new #{app_name} --skip-bundle" # Generate with the right version.
    cd app_name

    substitute = -> (file_name, regex, replacement) do
      File.write(file_name, File.read(file_name).sub(regex, replacement))
    end

    # Replace the generated gemfile entry with the exact version.
    substitute.call("Gemfile", /^gem "rails.*/, %{gem "rails", "#{releaser.version}"})
    substitute.call("Gemfile", /^# gem "image_processing/, 'gem "image_processing')
    sh "bundle"
    sh "rails action_mailbox:install"
    sh "rails action_text:install"

    sh "rails generate scaffold user name description:text admin:boolean"
    sh "rails db:migrate"

    # Replace the generated gemfile entry with the exact version.
    substitute.call("app/models/user.rb", /end\n\z/, <<~CODE)
        has_one_attached :avatar
        has_rich_text :description
      end
    CODE

    substitute.call("app/views/users/_form.html.erb", /textarea :description %>\n  <\/div>/, <<~CODE)
      rich_textarea :description %>\n  </div>

      <div class="field">
        Avatar: <%= form.file_field :avatar %>
      </div>
    CODE

    substitute.call("app/views/users/show.html.erb", /description %>\n<\/p>/, <<~CODE)
      description %>\n</p>

      <p>
        <% if @user.avatar.attached? -%>
          <%= image_tag @user.avatar.representation(resize_to_limit: [500, 500]) %>
        <% end -%>
      </p>
    CODE

    # Permit the avatar param.
    substitute.call("app/controllers/users_controller.rb", /:admin/, ":admin, :avatar")

    editor = ENV["VISUAL"] || ENV["EDITOR"]
    if editor
      `#{editor} #{File.expand_path(app_name)}`
    end

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
        f.puts "# Preparing for #{releaser.version} release\n"
        f.puts
        f.puts "# UNCOMMENT THE LINE ABOVE TO APPROVE THIS COMMIT"
      end

      sh "git add . && git commit --verbose --template=pkg/commit_message.txt"
      rm_f "pkg/commit_message.txt"
    end
  end

  task :tag do
    sh "git push"
    sh "git tag -s -m '#{releaser.tag} release' #{releaser.tag}"
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
      @version.include?("rc")
    end
  end
end

task :announce do
  Dir.chdir("pkg/") do
    versions = ENV["VERSIONS"] ? ENV["VERSIONS"].split(",") : [ releaser.version ]
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

    puts ERB.new(template, trim_mode: "<>").result(binding)
  end
end
