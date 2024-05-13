# frozen_string_literal: true

require "erb"
require "cgi"

# How to test:
#
#   export BUILDKITE_COMMIT="c8b601a225"
#   export BUILDKITE_BUILD_CREATOR="zzak"
#   export BUILDKITE_REPO="https://github.com/rails/rails.git"
#   export BUILDKITE_BUILD_NUMBER="60"
#   export BUILDKITE_BUILD_URL="https://buildkite.com/rails/docs-preview/builds/60"
#   export BUILDKITE_BRANCH="preview_docs"
#   export BUILDKITE_MESSAGE="commit message"
#   export BUILDKITE_PULL_REQUEST="42"
#   bundle exec rake preview_docs
#   open preview/index.html
class PreviewDocs
  attr_reader :commit, :author, :build, :repo, :branch

  def initialize
    @commit = link_to(EnvVars.sha[0, 7], "#{EnvVars.repo}/commit/#{EnvVars.sha}")
    @author = EnvVars.actor
    @build = link_to(EnvVars.build_number, EnvVars.build_url)
    @repo = link_to(EnvVars.repo_slug, "#{EnvVars.repo}")
    @branch = link_to(EnvVars.branch, "#{EnvVars.repo}/tree/#{EnvVars.branch}")
    @message = EnvVars.message || "n/a"
    @pull_request = EnvVars.pull_request ? link_to("##{EnvVars.pull_request}", "#{EnvVars.repo}/pull/#{EnvVars.pull_request}") : "n/a"
  end

  def render(outdir)
    template = File.open("tools/preview_docs/index.html.erb").read
    result = ERB.new(template).result(binding)
    File.open("#{outdir}/index.html", "w") do |f|
      f.write result
    end
  end

  def link_to(name, url)
    "<a href=\"#{escape(url)}\">#{escape(name)}</a>"
  end

  def escape(str)
    CGI.escapeHTML(str)
  end
end

module EnvVars
  def self.sha
    fetch "BUILDKITE_COMMIT"
  end

  def self.actor
    fetch "BUILDKITE_BUILD_CREATOR"
  end

  def self.repo
    fetch("BUILDKITE_REPO").gsub(".git", "")
  end

  def self.repo_slug
    repo.slice(/\w+\/\w+\Z/)
  end

  def self.build_number
    fetch "BUILDKITE_BUILD_NUMBER"
  end

  def self.build_url
    fetch "BUILDKITE_BUILD_URL"
  end

  def self.branch
    fetch "BUILDKITE_BRANCH"
  end

  def self.message
    ENV.fetch "BUILDKITE_MESSAGE"
  end

  def self.pull_request
    pr = ENV.fetch("BUILDKITE_PULL_REQUEST")
    pr == "false" ? false : pr
  end

  private
    def self.fetch(env)
      ENV.fetch(env) { raise "#{env} env var undefined!" }
    end
end
