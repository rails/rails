# Rails Plugin Manager.
# 
# Listing available plugins:
#
#   $ ./script/plugin list
#   continuous_builder            http://dev.rubyonrails.com/svn/rails/plugins/continuous_builder
#   asset_timestamping            http://svn.aviditybytes.com/rails/plugins/asset_timestamping
#   enumerations_mixin            http://svn.protocool.com/rails/plugins/enumerations_mixin/trunk
#   calculations                  http://techno-weenie.net/svn/projects/calculations/
#   ...
#
# Installing plugins:
#
#   $ ./script/plugin install continuous_builder asset_timestamping
#
# Finding Repositories:
#
#   $ ./script/plugin discover
# 
# Adding Repositories:
#
#   $ ./script/plugin source http://svn.protocool.com/rails/plugins/
#
# How it works:
# 
#   * Maintains a list of subversion repositories that are assumed to have
#     a plugin directory structure. Manage them with the (source, unsource,
#     and sources commands)
#     
#   * The discover command scrapes the following page for things that
#     look like subversion repositories with plugins:
#     http://wiki.rubyonrails.org/rails/pages/Plugins
# 
#   * If `vendor/plugins` is under subversion control, the script will
#     modify the svn:externals property and perform an update. You can
#     use normal subversion commands to keep the plugins up to date or
#     you can use the built in update command.
# 
#   * Or, if `vendor/plugins` is not under subversion control, the
#     plugin is pulled via `svn checkout` or `svn export` but looks
#     exactly the same.
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
      puts "plugin not found: #{name_uri_or_plugin}"
    end
  end
 
  def use_svn?
    `svn --version` rescue nil
    !$?.nil? && $?.success?
  end

  def use_externals?
    File.directory?("#{root}/vendor/plugins/.svn")
  end
  
  def use_checkout?
    # this is a bit of a guess. we assume that if the rails environment
    # is under subversion than they probably want the plugin checked out
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
    ext = `svn propget svn:externals #{root}/vendor/plugins`
    ext.reject{ |line| line.strip == '' }.map do |line| 
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
      system("svn propset -q svn:externals -F #{file.path} #{root}/vendor/plugins")
    end
  end
  
end

class Plugin
  attr_reader :name, :uri
  
  def initialize(uri, name=nil)
    @uri = uri
    guess_name(uri)
  end
  
  def to_s
    "#{@name.ljust(30)}#{@uri}"
  end
  
  def installed?
    File.directory?("#{rails_env.root}/vendor/plugins/#{name}") \
      or rails_env.externals.detect{ |name, repo| self.uri == repo }
  end
  
  def install(method=nil)
    method ||= rails_env.best_install_method?
    unless installed?
      send("install_using_#{method}")
    else
      puts "already installed: #{name} (#{uri})"
    end
  end
  
  private 
    def install_using_export
      root = rails_env.root
      mkdir_p "#{root}/vendor/plugins"
      system("svn export #{uri} #{root}/vendor/plugins/#{name}")
    end
    
    def install_using_checkout
      root = rails_env.root
      mkdir_p "#{root}/vendor/plugins"
      system("svn checkout #{uri} #{root}/vendor/plugins/#{name}")
    end
    
    def install_using_externals
      externals = rails_env.externals
      externals.push([@name, uri])
      rails_env.externals = externals
      install_using_checkout
    end

    def install_using_http
      root = rails_env.root
      mkdir_p "#{root}/vendor/plugins"
      Dir.chdir "#{root}/vendor/plugins"
      RecursiveHTTPFetcher.new(uri).fetch
    end

    def guess_name(url)
      @name = File.basename(url)
      if @name == 'trunk' || @name.empty?
        @name = File.basename(File.dirname(url))
      end
    end
    
    def rails_env
      @rails_env || RailsEnvironment.default
    end
end

class Repositories
  include Enumerable
  
  def initialize(cache_file = File.join(find_home, ".rails-plugin-sources"))
    @cache_file = File.expand_path(cache_file)
    load!
  end
  
  def each(&block)
    @repositories.each(&block)
  end
  
  def add(uri)
    unless find{|repo| repo.uri == uri }
      @repositories.push(Repository.new(uri)).last
    end
  end
  
  def remove(uri)
    @repositories.reject!{|repo| repo.uri == uri}
  end
  
  def exist?(uri)
    @repositories.detect{|repo| repo.uri == uri }
  end
  
  def all
    @repositories
  end
  
  def find_plugin(name)
    @repositories.each do |repo|
      repo.each do |plugin|
        return plugin if plugin.name == name
      end
    end
    
    return nil
  end
  
  def load!
    contents = File.exist?(@cache_file) ? File.read(@cache_file) : defaults
    contents = defaults if contents.empty?
    @repositories = contents.split(/\n/).reject do |line|
      line =~ /^\s*#/ or line =~ /^\s*$/
    end.map { |source| Repository.new(source.strip) }
  end
  
  def save
    File.open(@cache_file, 'w') do |f|
      each do |repo|
        f.write(repo.uri)
        f.write("\n")
      end
    end
  end
  
  def defaults
    <<-DEFAULTS
    http://dev.rubyonrails.com/svn/rails/plugins/
    DEFAULTS
  end
 
  def find_home
    ['HOME', 'USERPROFILE'].each do |homekey|
      return ENV[homekey] if ENV[homekey]
    end
    if ENV['HOMEDRIVE'] && ENV['HOMEPATH']
      return "#{ENV['HOMEDRIVE']}:#{ENV['HOMEPATH']}"
    end
    begin
      File.expand_path("~")
    rescue StandardError => ex
      if File::ALT_SEPARATOR
        "C:/"
      else
        "/"
      end
    end
  end

  def self.instance
    @instance ||= Repositories.new
  end
  
  def self.each(&block)
    self.instance.each(&block)
  end
end

class Repository
  include Enumerable
  attr_reader :uri, :plugins
  
  def initialize(uri)
    uri << "/" unless uri =~ /\/$/
    @uri = uri
    @plugins = nil
  end
  
  def plugins
    unless @plugins
      if $verbose
        puts "Discovering plugins in #{@uri}" 
        puts index
      end

      @plugins = index.split(/\n/).reject{ |line| line !~ /\/$/ }
      @plugins.map! { |name| Plugin.new(File.join(@uri, name), name) }
    end

    @plugins
  end
  
  def each(&block)
    plugins.each(&block)
  end
  
  private
    def index
      @index ||= `svn ls #{@uri}`
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
        o.banner =    "Usage: #{@script_name} [OPTIONS] command"
        o.define_head "Rails plugin manager."
        
        o.separator ""        
        o.separator "GENERAL OPTIONS"
        
        o.on("-r", "--root=DIR", String,
             "Set an explicit rails app directory.",
             "Default: #{@rails_root}") { |@rails_root| self.environment = RailsEnvironment.new(@rails_root) }
        o.on("-s", "--source=URL1,URL2", Array,
             "Use the specified plugin repositories instead of the defaults.") { |@sources|}
        
        o.on("-v", "--verbose", "Turn on verbose output.") { |$verbose| }
        o.on("-h", "--help", "Show this help message.") { puts o; exit }
        
        o.separator ""
        o.separator "COMMANDS"
        
        o.separator "  discover   Discover plugin repositories."
        o.separator "  list       List available plugins."
        o.separator "  install    Install plugin(s) from known repositories or URLs."
        o.separator "  update     Update installed plugins."
        o.separator "  remove     Uninstall plugins."
        o.separator "  source     Add a plugin source repository."
        o.separator "  unsource   Remove a plugin repository."
        o.separator "  sources    List currently configured plugin repositories."
        
        o.separator ""
        o.separator "EXAMPLES"
        o.separator "  Install a plugin:"
        o.separator "    #{@script_name} install continuous_builder\n"
        o.separator "  Install a plugin from a subversion URL:"
        o.separator "    #{@script_name} install http://dev.rubyonrails.com/svn/rails/plugins/continuous_builder\n"
        o.separator "  Install a plugin and add a svn:externals entry to vendor/plugins"
        o.separator "    #{@script_name} install -x continuous_builder\n"
        o.separator "  List all available plugins:"
        o.separator "    #{@script_name} list\n"
        o.separator "  List plugins in the specified repository:"
        o.separator "    #{@script_name} list --source=http://dev.rubyonrails.com/svn/rails/plugins/\n"
        o.separator "  Discover and prompt to add new repositories:"
        o.separator "    #{@script_name} discover\n"
        o.separator "  Discover new repositories but just list them, don't add anything:"
        o.separator "    #{@script_name} discover -l\n"
        o.separator "  Add a new repository to the source list:"
        o.separator "    #{@script_name} source http://dev.rubyonrails.com/svn/rails/plugins/\n"
        o.separator "  Remove a repository from the source list:"
        o.separator "    #{@script_name} unsource http://dev.rubyonrails.com/svn/rails/plugins/\n"
        o.separator "  Show currently configured repositories:"
        o.separator "    #{@script_name} sources\n"        
      end
    end
    
    def parse!(args=ARGV)
      general, sub = split_args(args)
      options.parse!(general)
      
      command = general.shift
      if command =~ /^(list|discover|install|source|unsource|sources|remove|update)$/
        command = Commands.const_get(command.capitalize).new(self)
        command.parse!(sub)
      else
        puts "Unknown command: #{command}"
        puts "Try: #{$0} --help"
        exit 1
      end
    end
    
    def split_args(args)
      left = []
      left << args.shift while args[0] and args[0] =~ /^-/
      left << args.shift if args[0]
      return [left, args]
    end
    
    def self.parse!(args=ARGV)
      Plugin.new.parse!(args)
    end
  end
  
  
  class List
    def initialize(base_command)
      @base_command = base_command
      @sources = []
      @local = false
      @remote = true
      @details = false
    end
    
    def options
      OptionParser.new do |o|
        o.set_summary_indent('  ')
        o.banner =    "Usage: #{@base_command.script_name} list [OPTIONS] [PATTERN]"
        o.define_head "List available plugins."
        o.separator   ""        
        o.separator   "Options:"
        o.separator   ""
        o.on(         "-s", "--source=URL1,URL2", Array,
                      "Use the specified plugin repositories.") {|@sources|}
        o.on(         "--local", 
                      "List locally installed plugins.") {|@local| @remote = false}
        o.on(         "--remote",
                      "List remotely availabled plugins. This is the default behavior",
                      "unless --local is provided.") {|@remote|}
        o.on(         "-l", "--long",
                      "Long listing / details about each plugin.") {|@details|}
      end
    end
    
    def parse!(args)
      options.order!(args)
      unless @sources.empty?
        @sources.map!{ |uri| Repository.new(uri) }
      else
        @sources = Repositories.instance.all
      end
      if @remote
        @sources.map{|r| r.plugins}.flatten.each do |plugin| 
          if @local or !plugin.installed?
            puts plugin.to_s
            system "svn info #{plugin.uri}" if @details
          end
        end
      else
        cd "#{@base_command.environment.root}/vendor/plugins"
        Dir["*"].select{|p| File.directory?(p)}.each do |name| 
          puts name
          system "svn info #{name}" if @details
        end
      end
    end
  end
  
  
  class Sources
    def initialize(base_command)
      @base_command = base_command
    end
    
    def options
      OptionParser.new do |o|
        o.set_summary_indent('  ')
        o.banner =    "Usage: #{@base_command.script_name} sources [OPTIONS] [PATTERN]"
        o.define_head "List configured plugin repositories."
        o.separator   ""        
        o.separator   "Options:"
        o.separator   ""
        o.on(         "-c", "--check", 
                      "Report status of repository.") { |@sources|}
      end
    end
    
    def parse!(args)
      options.parse!(args)
      Repositories.each do |repo|
        puts repo.uri
      end
    end
  end
  
  
  class Source
    def initialize(base_command)
      @base_command = base_command
    end
    
    def options
      OptionParser.new do |o|
        o.set_summary_indent('  ')
        o.banner =    "Usage: #{@base_command.script_name} source REPOSITORY"
        o.define_head "Add a new repository."
      end
    end
    
    def parse!(args)
      options.parse!(args)
      count = 0
      args.each do |uri|
        if Repositories.instance.add(uri)
          puts "added: #{uri.ljust(50)}" if $verbose
          count += 1
        else
          puts "failed: #{uri.ljust(50)}"
        end
      end
      Repositories.instance.save
      puts "Added #{count} repositories."
    end
  end
  
  
  class Unsource
    def initialize(base_command)
      @base_command = base_command
    end
    
    def options
      OptionParser.new do |o|
        o.set_summary_indent('  ')
        o.banner =    "Usage: #{@base_command.script_name} source URI [URI [URI]...]"
        o.define_head "Remove repositories from the default search list."
        o.separator ""
        o.on_tail("-h", "--help", "Show this help message.") { puts o; exit }
      end
    end
    
    def parse!(args)
      options.parse!(args)
      count = 0
      args.each do |uri|
        if Repositories.instance.remove(uri)
          count += 1
          puts "removed: #{uri.ljust(50)}"
        else
          puts "failed: #{uri.ljust(50)}"
        end
      end
      Repositories.instance.save
      puts "Removed #{count} repositories."
    end
  end

  
  class Discover
    def initialize(base_command)
      @base_command = base_command
      @list = false
      @prompt = true
    end
    
    def options
      OptionParser.new do |o|
        o.set_summary_indent('  ')
        o.banner =    "Usage: #{@base_command.script_name} discover URI [URI [URI]...]"
        o.define_head "Discover repositories referenced on a page."
        o.separator   ""        
        o.separator   "Options:"
        o.separator   ""
        o.on(         "-l", "--list", 
                      "List but don't prompt or add discovered repositories.") { |@list| @prompt = !@list }
        o.on(         "-n", "--no-prompt", 
                      "Add all new repositories without prompting.") { |v| @prompt = !v }
      end
    end

    def parse!(args)
      options.parse!(args)
      args = ['http://wiki.rubyonrails.org/rails/pages/Plugins'] if args.empty?
      args.each do |uri|
        scrape(uri) do |repo_uri|
          catch(:next_uri) do
            if @prompt
              begin
                $stdout.print "Add #{repo_uri}? [Y/n] "
                throw :next_uri if $stdin.gets !~ /^y?$/i
              rescue Interrupt
                $stdout.puts
                exit 1
              end
            elsif @list
              puts repo_uri
              throw :next_uri
            end
            Repositories.instance.add(repo_uri)
            puts "discovered: #{repo_uri}" if $verbose or !@prompt
          end
        end
      end
      Repositories.instance.save
    end
    
    def scrape(uri)
      require 'open-uri'
      puts "Scraping #{uri}" if $verbose
      dupes = []
      content = open(uri).each do |line|
        if line =~ /<a[^>]*href=['"]([^'"]*)['"]/
          uri = $1
          if uri =~ /\/plugins\// and uri !~ /\/browser\//
            uri = extract_repository_uri(uri)
            yield uri unless dupes.include?(uri) or Repositories.instance.exist?(uri)
            dupes << uri
          end
        end
      end
    end
    
    def extract_repository_uri(uri)
      uri.match(/(svn|https?):.*\/plugins\//i)[0]
    end 
  end
  
  class Install
    def initialize(base_command)
      @base_command = base_command
      @method = :export
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
      when (best == :export and (@method != :export and method != :http))
        msg = "Cannot install using #{requested} because this project is not under subversion."
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
      environment = @base_command.environment
      install_method = determine_install_method
      puts "Plugins will be installed using #{install_method}" if $verbose
      args.each do |name| 
        if name =~ /\// then
          ::Plugin.new(name).install(install_method)
        else
          plugin = Repositories.instance.find_plugin(name)
          unless plugin.nil?
            plugin.install(install_method)
          else
            puts "Plugin not found: #{name}"
            exit 1
          end
        end
      end
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
      root = @base_command.environment.root
      args.each do |name|
        path = "#{root}/vendor/plugins/#{name}"
        if File.directory?(path)
          rm_r path
        else
          puts "Plugin doesn't exist: #{path}"
        end
        # clean up svn:externals
        externals = @base_command.environment.externals
        externals.reject!{|n,u| name == n or name == u}
        @base_command.environment.externals = externals
      end
    end
  end

  class Update
    def initialize(base_command)
      @base_command = base_command
    end
    
    def options
      OptionParser.new do |o|
        o.set_summary_indent('  ')
        o.banner =    "Usage: #{@base_command.script_name} update [name [name]...]"
        o.define_head "Update plugins."
      end
    end
    
    def parse!(args)
      options.parse!(args)
      root = @base_command.environment.root
      args = Dir["#{root}/vendor/plugins/*"].map do |f|
        File.directory?("#{f}/.svn") ? File.basename(f) : nil
      end.compact if args.empty?
      cd "#{root}/vendor/plugins"
      args.each do |name|
        if File.directory?(name)
          puts "Updating plugin: #{name}"
          system("svn #{$verbose ? '' : '-q'} up #{name}")
        else
          puts "Plugin doesn't exist: #{name}"
        end
      end
    end
  end

end
 
class RecursiveHTTPFetcher
  def initialize(urls_to_fetch, cwd = ".")
    @cwd = cwd
    @urls_to_fetch = urls_to_fetch.to_a
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
      next if link =~ /^http/i || link =~ /^\./
      links << File.join(base_url, link)
    end
    links
  end
  
  def download(link)
    puts "+ #{File.join(@cwd, File.basename(link))}"
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
    push_d(File.basename(url))
    open(url) do |stream|
      contents =  stream.read
      fetch(links(url, contents))
    end
    pop_d
  end
end

Commands::Plugin.parse!
