# frozen_string_literal: true

require "open3"
require "json"

class Releaser
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
      if pre && pre.match?(/rc|beta|alpha/)
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
    if framework == "rails"
      glob = root + "version.rb"
    else
      glob = root + "#{framework}/lib/*/gem_version.rb"
    end

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

    framework_folder = "#{root}/#{framework}"

    package_json = "#{framework_folder}/package.json"

    if File.exist?(package_json) && JSON.parse(File.read(package_json))["version"] != npm_version
      Dir.chdir("#{framework_folder}") do
        if sh "which npm"
          sh "npm version #{npm_version} --no-git-tag-version"
        else
          raise "You must have npm installed to release Rails."
        end
      end
    end
  end

  def sh(command)
    Open3.capture3(command) do |_, _, _, wait_thread|
      exit_status = wait_thread.value
      exit_status.success?
    end
  end
end
