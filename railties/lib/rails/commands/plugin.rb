# Rails Plugin Manager.
#
# Installing plugins:
#
#   $ rails plugin install continuous_builder asset_timestamping
#
# Specifying revisions:
#
#   * Subversion revision is a single integer.
#
#   * Git revision format:
#     - full - 'refs/tags/1.8.0' or 'refs/heads/experimental'
#     - short: 'experimental' (equivalent to 'refs/heads/experimental')
#              'tag 1.8.0' (equivalent to 'refs/tags/1.8.0')
#
#
# This is Free Software, copyright 2005 by Ryan Tomayko (rtomayko@gmail.com)
# and is licensed MIT: (http://www.opensource.org/licenses/mit-license.php)

$verbose = false

require 'open-uri'
require 'fileutils'
require 'tempfile'

include FileUtils

class RailsEnvironment
  attr_reader :root

  def initialize(dir)
    @root = dir
  end

  def self.find(dir=nil)
    dir ||= pwd
    while dir.length > 1
      return new(dir) if File.exist?(File.join(dir, 'config', 'environment.rb'))
      dir = File.dirname(dir)
    end
  end

  def self.default
    @default ||= find
  end

  def self.default=(rails_env)
    @default = rails_env
  end

  def install(name_uri_or_plugin)
    if name_uri_or_plugin.is_a? String
      if name_uri_or_plugin =~ /:\/\//
        plugin = Plugin.new(name_uri_or_plugin)
      else
        plugin = Plugins[name_uri_or_plugin]
      end
    else
      plugin = name_uri_or_plugin
    end
    unless plugin.nil?
      plugin.install
    else
      puts "Plugin not found: #{name_uri_or_plugin}"
    end
  end

  def use_svn?
    require 'active_support/core_ext/kernel'
    silence_stderr {`svn --version` rescue nil}
    !$?.nil? && $?.success?
  end

  def use_externals?
    use_svn? && File.directory?("#{root}/vendor/plugins/.svn")
  end

  def use_checkout?
    # this is a bit of a guess. we assume that if the rails environment
    # is under subversion then they probably want the plugin checked out
    # instead of exported. This can be overridden on the command line
    File.directory?("#{root}/.svn")
  end

  def best_install_method
    return :http unless use_svn?
    case
      when use_externals? then :externals
      when use_checkout? then :checkout
      else :export
    end
  end

  def externals
    return [] unless use_externals?
    ext = `svn propget svn:externals "#{root}/vendor/plugins"`
    lines = ext.respond_to?(:lines) ? ext.lines : ext
    lines.reject{ |line| line.strip == '' }.map do |line|
      line.strip.split(/\s+/, 2)
    end
  end

  def externals=(items)
    unless items.is_a? String
      items = items.map{|name,uri| "#{name.ljust(29)} #{uri.chomp('/')}"}.join("\n")
    end
    Tempfile.open("svn-set-prop") do |file|
      file.write(items)
      file.flush
      system("svn propset -q svn:externals -F \"#{file.path}\" \"#{root}/vendor/plugins\"")
    end
  end
end

class Plugin
  attr_reader :name, :uri

  def initialize(uri, name = nil)
    @uri = uri
    guess_name(uri)
  end

  def self.find(name)
    new(name)
  end

  def to_s
    "#{@name.ljust(30)}#{@uri}"
  end

  def svn_url?
    @uri =~ /svn(?:\+ssh)?:\/\/*/
  end

  def git_url?
    @uri =~ /^git:\/\// || @uri =~ /\.git$/
  end

  def installed?
    File.directory?("#{rails_env.root}/vendor/plugins/#{name}") \
      or rails_env.externals.detect{ |name, repo| self.uri == repo }
  end

  def install(method=nil, options = {})
    method ||= rails_env.best_install_method?
    if :http == method
      method = :export if svn_url?
      method = :git    if git_url?
    end

    uninstall if installed? and options[:force]

    unless installed?
      send("install_using_#{method}", options)
      run_install_hook
    else
      puts "already installed: #{name} (#{uri}).  pass --force to reinstall"
    end
  end

  def uninstall
    path = "#{rails_env.root}/vendor/plugins/#{name}"
    if File.directory?(path)
      puts "Removing 'vendor/plugins/#{name}'" if $verbose
      run_uninstall_hook
      rm_r path
    else
      puts "Plugin doesn't exist: #{path}"
    end

    if rails_env.use_externals?
      # clean up svn:externals
      externals = rails_env.externals
      externals.reject!{|n, u| name == n or name == u}
      rails_env.externals = externals
    end
  end

  def info
    tmp = "#{rails_env.root}/_tmp_about.yml"
    if svn_url?
      cmd = "svn export #{@uri} \"#{rails_env.root}/#{tmp}\""
      puts cmd if $verbose
      system(cmd)
    end
    open(svn_url? ? tmp : File.join(@uri, 'about.yml')) do |stream|
      stream.read
    end rescue "No about.yml found in #{uri}"
  ensure
    FileUtils.rm_rf tmp if svn_url?
  end

  private

    def run_install_hook
      install_hook_file = "#{rails_env.root}/vendor/plugins/#{name}/install.rb"
      load install_hook_file if File.exist? install_hook_file
    end

    def run_uninstall_hook
      uninstall_hook_file = "#{rails_env.root}/vendor/plugins/#{name}/uninstall.rb"
      load uninstall_hook_file if File.exist? uninstall_hook_file
    end

    def install_using_export(options = {})
      svn_command :export, options
    end

    def install_using_checkout(options = {})
      svn_command :checkout, options
    end

    def install_using_externals(options = {})
      externals = rails_env.externals
      externals.push([@name, uri])
      rails_env.externals = externals
      install_using_checkout(options)
    end

    def install_using_http(options = {})
      root = rails_env.root
      mkdir_p "#{root}/vendor/plugins/#{@name}"
      Dir.chdir "#{root}/vendor/plugins/#{@name}" do
        puts "fetching from '#{uri}'" if $verbose
        fetcher = RecursiveHTTPFetcher.new(uri, -1)
        fetcher.quiet = true if options[:quiet]
        fetcher.fetch
      end
    end

    def install_using_git(options = {})
      root = rails_env.root
      mkdir_p(install_path = "#{root}/vendor/plugins/#{name}")
      Dir.chdir install_path do
        init_cmd = "git init"
        init_cmd += " -q" if options[:quiet] and not $verbose
        puts init_cmd if $verbose
        system(init_cmd)
        base_cmd = "git pull --depth 1 #{uri}"
        base_cmd += " -q" if options[:quiet] and not $verbose
        base_cmd += " #{options[:revision]}" if options[:revision]
        puts base_cmd if $verbose
        if system(base_cmd)
          puts "removing: .git .gitignore" if $verbose
          rm_rf %w(.git .gitignore)
        else
          rm_rf install_path
        end
      end
    end

    def svn_command(cmd, options = {})
      root = rails_env.root
      mkdir_p "#{root}/vendor/plugins"
      base_cmd = "svn #{cmd} #{uri} \"#{root}/vendor/plugins/#{name}\""
      base_cmd += ' -q' if options[:quiet] and not $verbose
      base_cmd += " -r #{options[:revision]}" if options[:revision]
      puts base_cmd if $verbose
      system(base_cmd)
    end

    def guess_name(url)
      @name = File.basename(url)
      if @name == 'trunk' || @name.empty?
        @name = File.basename(File.dirname(url))
      end
      @name.gsub!(/\.git$/, '') if @name =~ /\.git$/
    end

    def rails_env
      @rails_env || RailsEnvironment.default
    end
end

# load default environment and parse arguments
require 'optparse'
module Commands
  class Plugin
    attr_reader :environment, :script_name, :sources
    def initialize
      @environment = RailsEnvironment.default
      @rails_root = RailsEnvironment.default.root
      @script_name = File.basename($0)
      @sources = []
    end

    def environment=(value)
      @environment = value
      RailsEnvironment.default = value
    end

    def options
      OptionParser.new do |o|
        o.set_summary_indent('  ')
        o.banner =    "Usage: plugin [OPTIONS] command"
        o.define_head "Rails plugin manager."

        o.separator ""
        o.separator "GENERAL OPTIONS"

        o.on("-r", "--root=DIR", String,
             "Set an explicit rails app directory.",
             "Default: #{@rails_root}") { |rails_root| @rails_root = rails_root; self.environment = RailsEnvironment.new(@rails_root) }
        o.on("-s", "--source=URL1,URL2", Array,
             "Use the specified plugin repositories instead of the defaults.") { |sources| @sources = sources}

        o.on("-v", "--verbose", "Turn on verbose output.") { |verbose| $verbose = verbose }
        o.on("-h", "--help", "Show this help message.") { puts o; exit }

        o.separator ""
        o.separator "COMMANDS"

        o.separator "  install    Install plugin(s) from known repositories or URLs."
        o.separator "  remove     Uninstall plugins."

        o.separator ""
        o.separator "EXAMPLES"
        o.separator "  Install a plugin:"
        o.separator "    #{@script_name} plugin install continuous_builder\n"
        o.separator "  Install a plugin from a subversion URL:"
        o.separator "    #{@script_name} plugin install http://dev.rubyonrails.com/svn/rails/plugins/continuous_builder\n"
        o.separator "  Install a plugin from a git URL:"
        o.separator "    #{@script_name} plugin install git://github.com/SomeGuy/my_awesome_plugin.git\n"
        o.separator "  Install a plugin and add a svn:externals entry to vendor/plugins"
        o.separator "    #{@script_name} plugin install -x continuous_builder\n"
      end
    end

    def parse!(args=ARGV)
      general, sub = split_args(args)
      options.parse!(general)

      command = general.shift
      if command =~ /^(install|remove)$/
        command = Commands.const_get(command.capitalize).new(self)
        command.parse!(sub)
      else
        puts "Unknown command: #{command}" unless command.blank?
        puts options
        exit 1
      end
    end

    def split_args(args)
      left = []
      left << args.shift while args[0] and args[0] =~ /^-/
      left << args.shift if args[0]
      [left, args]
    end

    def self.parse!(args=ARGV)
      Plugin.new.parse!(args)
    end
  end

  class Install
    def initialize(base_command)
      @base_command = base_command
      @method = :http
      @options = { :quiet => false, :revision => nil, :force => false }
    end

    def options
      OptionParser.new do |o|
        o.set_summary_indent('  ')
        o.banner =    "Usage: #{@base_command.script_name} install PLUGIN [PLUGIN [PLUGIN] ...]"
        o.define_head "Install one or more plugins."
        o.separator   ""
        o.separator   "Options:"
        o.on(         "-x", "--externals",
                      "Use svn:externals to grab the plugin.",
                      "Enables plugin updates and plugin versioning.") { |v| @method = :externals }
        o.on(         "-o", "--checkout",
                      "Use svn checkout to grab the plugin.",
                      "Enables updating but does not add a svn:externals entry.") { |v| @method = :checkout }
        o.on(         "-e", "--export",
                      "Use svn export to grab the plugin.",
                      "Exports the plugin, allowing you to check it into your local repository. Does not enable updates, or add an svn:externals entry.") { |v| @method = :export }
        o.on(         "-q", "--quiet",
                      "Suppresses the output from installation.",
                      "Ignored if -v is passed (rails plugin -v install ...)") { |v| @options[:quiet] = true }
        o.on(         "-r REVISION", "--revision REVISION",
                      "Checks out the given revision from subversion or git.",
                      "Ignored if subversion/git is not used.") { |v| @options[:revision] = v }
        o.on(         "-f", "--force",
                      "Reinstalls a plugin if it's already installed.") { |v| @options[:force] = true }
        o.separator   ""
        o.separator   "You can specify plugin names as given in 'plugin list' output or absolute URLs to "
        o.separator   "a plugin repository."
      end
    end

    def determine_install_method
      best = @base_command.environment.best_install_method
      @method = :http if best == :http and @method == :export
      case
      when (best == :http and @method != :http)
        msg = "Cannot install using subversion because `svn' cannot be found in your PATH"
      when (best == :export and (@method != :export and @method != :http))
        msg = "Cannot install using #{@method} because this project is not under subversion."
      when (best != :externals and @method == :externals)
        msg = "Cannot install using externals because vendor/plugins is not under subversion."
      end
      if msg
        puts msg
        exit 1
      end
      @method
    end

    def parse!(args)
      options.parse!(args)
      if args.blank?
        puts options
        exit 1
      end
      environment = @base_command.environment
      install_method = determine_install_method
      puts "Plugins will be installed using #{install_method}" if $verbose
      args.each do |name|
        ::Plugin.find(name).install(install_method, @options)
      end
    rescue StandardError => e
      puts "Plugin not found: #{args.inspect}"
      puts e.inspect if $verbose
      exit 1
    end
  end

  class Remove
    def initialize(base_command)
      @base_command = base_command
    end

    def options
      OptionParser.new do |o|
        o.set_summary_indent('  ')
        o.banner =    "Usage: #{@base_command.script_name} remove name [name]..."
        o.define_head "Remove plugins."
      end
    end

    def parse!(args)
      options.parse!(args)
      if args.blank?
        puts options
        exit 1
      end
      root = @base_command.environment.root
      args.each do |name|
        ::Plugin.new(name).uninstall
      end
    end
  end

  class Info
    def initialize(base_command)
      @base_command = base_command
    end

    def options
      OptionParser.new do |o|
        o.set_summary_indent('  ')
        o.banner =    "Usage: #{@base_command.script_name} info name [name]..."
        o.define_head "Shows plugin info at {url}/about.yml."
      end
    end

    def parse!(args)
      options.parse!(args)
      args.each do |name|
        puts ::Plugin.find(name).info
        puts
      end
    end
  end
end

class RecursiveHTTPFetcher
  attr_accessor :quiet
  def initialize(urls_to_fetch, level = 1, cwd = ".")
    @level = level
    @cwd = cwd
    @urls_to_fetch = RUBY_VERSION >= '1.9' ? urls_to_fetch.lines : urls_to_fetch.to_a
    @quiet = false
  end

  def ls
    @urls_to_fetch.collect do |url|
      if url =~ /^svn(\+ssh)?:\/\/.*/
        `svn ls #{url}`.split("\n").map {|entry| "/#{entry}"} rescue nil
      else
        open(url) do |stream|
          links("", stream.read)
        end rescue nil
      end
    end.flatten
  end

  def push_d(dir)
    @cwd = File.join(@cwd, dir)
    FileUtils.mkdir_p(@cwd)
  end

  def pop_d
    @cwd = File.dirname(@cwd)
  end

  def links(base_url, contents)
    links = []
    contents.scan(/href\s*=\s*\"*[^\">]*/i) do |link|
      link = link.sub(/href="/i, "")
      next if link =~ /svnindex.xsl$/
      next if link =~ /^(\w*:|)\/\// || link =~ /^\./
      links << File.join(base_url, link)
    end
    links
  end

  def download(link)
    puts "+ #{File.join(@cwd, File.basename(link))}" unless @quiet
    open(link) do |stream|
      File.open(File.join(@cwd, File.basename(link)), "wb") do |file|
        file.write(stream.read)
      end
    end
  end

  def fetch(links = @urls_to_fetch)
    links.each do |l|
      (l =~ /\/$/ || links == @urls_to_fetch) ? fetch_dir(l) : download(l)
    end
  end

  def fetch_dir(url)
    @level += 1
    push_d(File.basename(url)) if @level > 0
    open(url) do |stream|
      contents =  stream.read
      fetch(links(url, contents))
    end
    pop_d if @level > 0
    @level -= 1
  end
end

Commands::Plugin.parse!
