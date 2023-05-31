# frozen_string_literal: true

require "erb"
require "cgi"

puts "required tools/preview_docs"

# How to test
#
#   export GITHUB_SERVER_URL="https://github.com"
#   export GITHUB_REPOSITORY="zzak/rails"
#   export GITHUB_REF_NAME="cf-pages"
#   export GITHUB_SHA="45efdc016e00a79861527a87e341a2d57badee55"
#   export GITHUB_RUN_ID="5127901781"
#   export GITHUB_ACTOR="<script type=\"text/javascript\">alert('gotcha')</script>"
#   bundle exec rake preview_docs
class PreviewDocs
  attr_reader :commit, :author, :run, :repo, :branch

  def initialize
    @commit = link_to(EnvVars.sha[0, 7], "#{EnvVars.repo_url}/commit/#{EnvVars.sha}")
    @author = link_to(EnvVars.actor, "#{EnvVars.host}/#{EnvVars.actor}")
    @run = link_to(EnvVars.run, "#{EnvVars.repo_url}/actions/runs/#{EnvVars.run}")
    @repo = link_to(EnvVars.repo, "#{EnvVars.repo_url}")
    @branch = link_to(EnvVars.ref, "#{EnvVars.repo_url}/tree/#{EnvVars.ref}")
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
    fetch "GITHUB_SHA"
  end

  def self.actor
    fetch "GITHUB_ACTOR"
  end

  def self.host
    fetch "GITHUB_SERVER_URL"
  end

  def self.repo
    fetch "GITHUB_REPOSITORY"
  end

  def self.repo_url
    "#{host}/#{repo}"
  end

  def self.run
    fetch "GITHUB_RUN_ID"
  end

  def self.ref
    fetch "GITHUB_REF_NAME"
  end

  private
    def self.fetch(env)
      ENV.fetch(env) { raise "#{env} env var undefined!" }
    end
end
