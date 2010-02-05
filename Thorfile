require "active_support"

module GemHelpers

  def generate_gemspec
    $LOAD_PATH << "#{File.dirname(__FILE__)}/vendor/rails/activerecord/lib"
    $LOAD_PATH << "#{File.dirname(__FILE__)}/vendor/rails/activesupport/lib"

    $LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), "lib")))
    require "arel"

    Gem::Specification.new do |s|
      s.name      = "arel"
      s.version   = Arel::VERSION
      s.authors   = ["Bryan Helmkamp", "Nick Kallen", "Emilio Tagua"]
      s.email     = "bryan@brynary.com"
      s.homepage  = "http://github.com/brynary/arel"
      s.summary   = "Arel is a relational algebra engine for Ruby"
      s.description  = <<-EOS.strip
Arel is a Relational Algebra for Ruby. It 1) simplifies the generation complex
of SQL queries and it 2) adapts to various RDBMS systems. It is intended to be
a framework framework; that is, you can build your own ORM with it, focusing on
innovative object and collection modeling as opposed to database compatibility
and query generation.
      EOS
      s.rubyforge_project = "arel"

      require "git"
      repo = Git.open(".")

      s.files      = normalize_files(repo.ls_files.keys - repo.lib.ignored_files)
      s.test_files = normalize_files(Dir['spec/**/*.rb'] - repo.lib.ignored_files)

      s.has_rdoc = true
      s.extra_rdoc_files = %w[History.txt README.markdown]

      # Arel required ActiveRecord, but we're not declaring it to avoid a
      # circular dependency chain. The solution is for ActiveRecord to release
      # the connection adapters which Arel uses in a separate gem
      # s.add_dependency "activerecord", ">= 3.0.pre"
      s.add_dependency "activesupport", ">= 3.0.0.beta"
    end
  end

  def normalize_files(array)
    # only keep files, no directories, and sort
    array.select do |path|
      File.file?(path)
    end.sort
  end

  # Adds extra space when outputting an array. This helps create better version
  # control diffs, because otherwise it is all on the same line.
  def prettyify_array(gemspec_ruby, array_name)
    gemspec_ruby.gsub(/s\.#{array_name.to_s} = \[.+?\]/) do |match|
      leadin, files = match[0..-2].split("[")
      leadin + "[\n    #{files.split(",").join(",\n   ")}\n  ]"
    end
  end

  def read_gemspec
    @read_gemspec ||= eval(File.read("arel.gemspec"))
  end

  def sh(command)
    puts command
    system command
  end
end

class Default < Thor
  include GemHelpers

  desc "gemspec", "Regenerate arel.gemspec"
  def gemspec
    File.open("arel.gemspec", "w") do |file|
      gemspec_ruby = generate_gemspec.to_ruby
      gemspec_ruby = prettyify_array(gemspec_ruby, :files)
      gemspec_ruby = prettyify_array(gemspec_ruby, :test_files)
      gemspec_ruby = prettyify_array(gemspec_ruby, :extra_rdoc_files)

      file.write gemspec_ruby
    end

    puts "Wrote gemspec to arel.gemspec"
    read_gemspec.validate
  end

  desc "build", "Build a arel gem"
  def build
    sh "gem build arel.gemspec"
    FileUtils.mkdir_p "pkg"
    FileUtils.mv read_gemspec.file_name, "pkg"
  end

  desc "install", "Install the latest built gem"
  def install
    sh "gem install --local pkg/#{read_gemspec.file_name}"
  end

  desc "release", "Release the current branch to GitHub and Gemcutter"
  def release
    gemspec
    build
    Release.new.tag
    Release.new.gem
  end
end

class Release < Thor
  include GemHelpers

  desc "tag", "Tag the gem on the origin server"
  def tag
    release_tag = "v#{read_gemspec.version}"
    sh "git tag -a #{release_tag} -m 'Tagging #{release_tag}'"
    sh "git push origin #{release_tag}"
  end

  desc "gem", "Push the gem to Gemcutter"
  def gem
    sh "gem push pkg/#{read_gemspec.file_name}"
  end
end