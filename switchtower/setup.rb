#
# setup.rb
#
# Copyright (c) 2000-2004 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU Lesser General Public License version 2.1.
#

#
# For backward compatibility
#

unless Enumerable.method_defined?(:map)
  module Enumerable
    alias map collect
  end
end

unless Enumerable.method_defined?(:detect)
  module Enumerable
    alias detect find
  end
end

unless Enumerable.method_defined?(:select)
  module Enumerable
    alias select find_all
  end
end

unless Enumerable.method_defined?(:reject)
  module Enumerable
    def reject
      result = []
      each do |i|
        result.push i unless yield(i)
      end
      result
    end
  end
end

unless Enumerable.method_defined?(:inject)
  module Enumerable
    def inject(result)
      each do |i|
        result = yield(result, i)
      end
      result
    end
  end
end

unless Enumerable.method_defined?(:any?)
  module Enumerable
    def any?
      each do |i|
        return true if yield(i)
      end
      false
    end
  end
end

unless File.respond_to?(:read)
  def File.read(fname)
    open(fname) {|f|
      return f.read
    }
  end
end

#
# Application independent utilities
#

def File.binread(fname)
  open(fname, 'rb') {|f|
    return f.read
  }
end

# for corrupted windows stat(2)
def File.dir?(path)
  File.directory?((path[-1,1] == '/') ? path : path + '/')
end

#
# Config
#

if arg = ARGV.detect{|arg| /\A--rbconfig=/ =~ arg }
  ARGV.delete(arg)
  require arg.split(/=/, 2)[1]
  $".push 'rbconfig.rb'
else
  require 'rbconfig'
end

def multipackage_install?
  FileTest.directory?(File.dirname($0) + '/packages')
end


class ConfigTable

  c = ::Config::CONFIG

  rubypath = c['bindir'] + '/' + c['ruby_install_name']

  major = c['MAJOR'].to_i
  minor = c['MINOR'].to_i
  teeny = c['TEENY'].to_i
  version = "#{major}.#{minor}"

  # ruby ver. >= 1.4.4?
  newpath_p = ((major >= 2) or
               ((major == 1) and
                ((minor >= 5) or
                 ((minor == 4) and (teeny >= 4)))))
  
  subprefix = lambda {|path|
    path.sub(/\A#{Regexp.quote(c['prefix'])}/o, '$prefix')
  }

  if c['rubylibdir']
    # V < 1.6.3
    stdruby    = subprefix.call(c['rubylibdir'])
    siteruby   = subprefix.call(c['sitedir'])
    versite    = subprefix.call(c['sitelibdir'])
    sodir      = subprefix.call(c['sitearchdir'])
  elsif newpath_p
    # 1.4.4 <= V <= 1.6.3
    stdruby    = "$prefix/lib/ruby/#{version}"
    siteruby   = subprefix.call(c['sitedir'])
    versite    = siteruby + '/' + version
    sodir      = "$site-ruby/#{c['arch']}"
  else
    # V < 1.4.4
    stdruby    = "$prefix/lib/ruby/#{version}"
    siteruby   = "$prefix/lib/ruby/#{version}/site_ruby"
    versite    = siteruby
    sodir      = "$site-ruby/#{c['arch']}"
  end

  if arg = c['configure_args'].split.detect {|arg| /--with-make-prog=/ =~ arg }
    makeprog = arg.sub(/'/, '').split(/=/, 2)[1]
  else
    makeprog = 'make'
  end

  common_descripters = [
    [ 'prefix',    [ c['prefix'],
                     'path',
                     'path prefix of target environment' ] ],
    [ 'std-ruby',  [ stdruby,
                     'path',
                     'the directory for standard ruby libraries' ] ],
    [ 'site-ruby-common', [ siteruby,
                     'path',
                     'the directory for version-independent non-standard ruby libraries' ] ],
    [ 'site-ruby', [ versite,
                     'path',
                     'the directory for non-standard ruby libraries' ] ],
    [ 'bin-dir',   [ '$prefix/bin',
                     'path',
                     'the directory for commands' ] ],
    [ 'rb-dir',    [ '$site-ruby',
                     'path',
                     'the directory for ruby scripts' ] ],
    [ 'so-dir',    [ sodir,
                     'path',
                     'the directory for ruby extentions' ] ],
    [ 'data-dir',  [ '$prefix/share',
                     'path',
                     'the directory for shared data' ] ],
    [ 'ruby-path', [ rubypath,
                     'path',
                     'path to set to #! line' ] ],
    [ 'ruby-prog', [ rubypath,
                     'name',
                     'the ruby program using for installation' ] ],
    [ 'make-prog', [ makeprog,
                     'name',
                     'the make program to compile ruby extentions' ] ],
    [ 'without-ext', [ 'no',
                       'yes/no',
                       'does not compile/install ruby extentions' ] ]
  ]
  multipackage_descripters = [
    [ 'with',      [ '',
                     'name,name...',
                     'package names that you want to install',
                     'ALL' ] ],
    [ 'without',   [ '',
                     'name,name...',
                     'package names that you do not want to install',
                     'NONE' ] ]
  ]
  if multipackage_install?
    DESCRIPTER = common_descripters + multipackage_descripters
  else
    DESCRIPTER = common_descripters
  end

  SAVE_FILE = 'config.save'

  def ConfigTable.each_name(&block)
    keys().each(&block)
  end

  def ConfigTable.keys
    DESCRIPTER.map {|name, *dummy| name }
  end

  def ConfigTable.each_definition(&block)
    DESCRIPTER.each(&block)
  end

  def ConfigTable.get_entry(name)
    name, ent = DESCRIPTER.assoc(name)
    ent
  end

  def ConfigTable.get_entry!(name)
    get_entry(name) or raise ArgumentError, "no such config: #{name}"
  end

  def ConfigTable.add_entry(name, vals)
    ConfigTable::DESCRIPTER.push [name,vals]
  end

  def ConfigTable.remove_entry(name)
    get_entry(name) or raise ArgumentError, "no such config: #{name}"
    DESCRIPTER.delete_if {|n, arr| n == name }
  end

  def ConfigTable.config_key?(name)
    get_entry(name) ? true : false
  end

  def ConfigTable.bool_config?(name)
    ent = get_entry(name) or return false
    ent[1] == 'yes/no'
  end

  def ConfigTable.value_config?(name)
    ent = get_entry(name) or return false
    ent[1] != 'yes/no'
  end

  def ConfigTable.path_config?(name)
    ent = get_entry(name) or return false
    ent[1] == 'path'
  end


  class << self
    alias newobj new
  end

  def ConfigTable.new
    c = newobj()
    c.initialize_from_table
    c
  end

  def ConfigTable.load
    c = newobj()
    c.initialize_from_file
    c
  end

  def initialize_from_table
    @table = {}
    DESCRIPTER.each do |k, (default, vname, desc, default2)|
      @table[k] = default
    end
  end

  def initialize_from_file
    raise InstallError, "#{File.basename $0} config first"\
        unless File.file?(SAVE_FILE)
    @table = {}
    File.foreach(SAVE_FILE) do |line|
      k, v = line.split(/=/, 2)
      @table[k] = v.strip
    end
  end

  def save
    File.open(SAVE_FILE, 'w') {|f|
      @table.each do |k, v|
        f.printf "%s=%s\n", k, v if v
      end
    }
  end

  def []=(k, v)
    raise InstallError, "unknown config option #{k}"\
        unless ConfigTable.config_key?(k)
    @table[k] = v
  end
    
  def [](key)
    return nil unless @table[key]
    @table[key].gsub(%r<\$([^/]+)>) { self[$1] }
  end

  def set_raw(key, val)
    @table[key] = val
  end

  def get_raw(key)
    @table[key]
  end

end


module MetaConfigAPI

  def eval_file_ifexist(fname)
    instance_eval File.read(fname), fname, 1 if File.file?(fname)
  end

  def config_names
    ConfigTable.keys
  end

  def config?(name)
    ConfigTable.config_key?(name)
  end

  def bool_config?(name)
    ConfigTable.bool_config?(name)
  end

  def value_config?(name)
    ConfigTable.value_config?(name)
  end

  def path_config?(name)
    ConfigTable.path_config?(name)
  end

  def add_config(name, argname, default, desc)
    ConfigTable.add_entry name,[default,argname,desc]
  end

  def add_path_config(name, default, desc)
    add_config name, 'path', default, desc
  end

  def add_bool_config(name, default, desc)
    add_config name, 'yes/no', default ? 'yes' : 'no', desc
  end

  def set_config_default(name, default)
    if bool_config?(name)
      ConfigTable.get_entry!(name)[0] = (default ? 'yes' : 'no')
    else
      ConfigTable.get_entry!(name)[0] = default
    end
  end

  def remove_config(name)
    ent = ConfigTable.get_entry(name)
    ConfigTable.remove_entry name
    ent
  end

end

#
# File Operations
#

module FileOperations

  def mkdir_p(dirname, prefix = nil)
    dirname = prefix + dirname if prefix
    $stderr.puts "mkdir -p #{dirname}" if verbose?
    return if no_harm?

    # does not check '/'... it's too abnormal case
    dirs = dirname.split(%r<(?=/)>)
    if /\A[a-z]:\z/i =~ dirs[0]
      disk = dirs.shift
      dirs[0] = disk + dirs[0]
    end
    dirs.each_index do |idx|
      path = dirs[0..idx].join('')
      Dir.mkdir path unless File.dir?(path)
    end
  end

  def rm_f(fname)
    $stderr.puts "rm -f #{fname}" if verbose?
    return if no_harm?

    if File.exist?(fname) or File.symlink?(fname)
      File.chmod 0777, fname
      File.unlink fname
    end
  end

  def rm_rf(dn)
    $stderr.puts "rm -rf #{dn}" if verbose?
    return if no_harm?

    Dir.chdir dn
    Dir.foreach('.') do |fn|
      next if fn == '.'
      next if fn == '..'
      if File.dir?(fn)
        verbose_off {
          rm_rf fn
        }
      else
        verbose_off {
          rm_f fn
        }
      end
    end
    Dir.chdir '..'
    Dir.rmdir dn
  end

  def move_file(src, dest)
    File.unlink dest if File.exist?(dest)
    begin
      File.rename src, dest
    rescue
      File.open(dest, 'wb') {|f| f.write File.binread(src) }
      File.chmod File.stat(src).mode, dest
      File.unlink src
    end
  end

  def install(from, dest, mode, prefix = nil)
    $stderr.puts "install #{from} #{dest}" if verbose?
    return if no_harm?

    realdest = prefix + dest if prefix
    realdest = File.join(realdest, File.basename(from)) if File.dir?(realdest)
    str = File.binread(from)
    if diff?(str, realdest)
      verbose_off {
        rm_f realdest if File.exist?(realdest)
      }
      File.open(realdest, 'wb') {|f|
        f.write str
      }
      File.chmod mode, realdest

      File.open("#{objdir_root()}/InstalledFiles", 'a') {|f|
        if prefix
          f.puts realdest.sub(prefix, '')
        else
          f.puts realdest
        end
      }
    end
  end

  def diff?(new_content, path)
    return true unless File.exist?(path)
    new_content != File.binread(path)
  end

  def command(str)
    $stderr.puts str if verbose?
    system str or raise RuntimeError, "'system #{str}' failed"
  end

  def ruby(str)
    command config('ruby-prog') + ' ' + str
  end
  
  def make(task = '')
    command config('make-prog') + ' ' + task
  end

  def extdir?(dir)
    File.exist?(dir + '/MANIFEST')
  end

  def all_files_in(dirname)
    Dir.open(dirname) {|d|
      return d.select {|ent| File.file?("#{dirname}/#{ent}") }
    }
  end

  REJECT_DIRS = %w(
    CVS SCCS RCS CVS.adm .svn
  )

  def all_dirs_in(dirname)
    Dir.open(dirname) {|d|
      return d.select {|n| File.dir?("#{dirname}/#{n}") } - %w(. ..) - REJECT_DIRS
    }
  end

end

#
# Main Installer
#

class InstallError < StandardError; end


module HookUtils

  def run_hook(name)
    try_run_hook "#{curr_srcdir()}/#{name}" or
    try_run_hook "#{curr_srcdir()}/#{name}.rb"
  end

  def try_run_hook(fname)
    return false unless File.file?(fname)
    begin
      instance_eval File.read(fname), fname, 1
    rescue
      raise InstallError, "hook #{fname} failed:\n" + $!.message
    end
    true
  end

end


module HookScriptAPI

  def get_config(key)
    @config[key]
  end

  alias config get_config

  def set_config(key, val)
    @config[key] = val
  end

  #
  # srcdir/objdir (works only in the package directory)
  #

  #abstract srcdir_root
  #abstract objdir_root
  #abstract relpath

  def curr_srcdir
    "#{srcdir_root()}/#{relpath()}"
  end

  def curr_objdir
    "#{objdir_root()}/#{relpath()}"
  end

  def srcfile(path)
    "#{curr_srcdir()}/#{path}"
  end

  def srcexist?(path)
    File.exist?(srcfile(path))
  end

  def srcdirectory?(path)
    File.dir?(srcfile(path))
  end
  
  def srcfile?(path)
    File.file? srcfile(path)
  end

  def srcentries(path = '.')
    Dir.open("#{curr_srcdir()}/#{path}") {|d|
      return d.to_a - %w(. ..)
    }
  end

  def srcfiles(path = '.')
    srcentries(path).select {|fname|
      File.file?(File.join(curr_srcdir(), path, fname))
    }
  end

  def srcdirectories(path = '.')
    srcentries(path).select {|fname|
      File.dir?(File.join(curr_srcdir(), path, fname))
    }
  end

end


class ToplevelInstaller

  Version   = '3.2.4'
  Copyright = 'Copyright (c) 2000-2004 Minero Aoki'

  TASKS = [
    [ 'config',   'saves your configurations' ],
    [ 'show',     'shows current configuration' ],
    [ 'setup',    'compiles ruby extentions and others' ],
    [ 'install',  'installs files' ],
    [ 'clean',    "does `make clean' for each extention" ],
    [ 'distclean',"does `make distclean' for each extention" ]
  ]

  def ToplevelInstaller.invoke
    instance().invoke
  end

  @singleton = nil

  def ToplevelInstaller.instance
    @singleton ||= new(File.dirname($0))
    @singleton
  end

  include MetaConfigAPI

  def initialize(ardir_root)
    @config = nil
    @options = { 'verbose' => true }
    @ardir = File.expand_path(ardir_root)
  end

  def inspect
    "#<#{self.class} #{__id__()}>"
  end

  def invoke
    run_metaconfigs
    task = parsearg_global()
    @config = load_config(task)
    __send__ "parsearg_#{task}"
    init_installers
    __send__ "exec_#{task}"
  end

  def run_metaconfigs
    eval_file_ifexist "#{@ardir}/metaconfig"
  end

  def load_config(task)
    case task
    when 'config'
      ConfigTable.new
    when 'clean', 'distclean'
      if File.exist?('config.save')
      then ConfigTable.load
      else ConfigTable.new
      end
    else
      ConfigTable.load
    end
  end

  def init_installers
    @installer = Installer.new(@config, @options, @ardir, File.expand_path('.'))
  end

  #
  # Hook Script API bases
  #

  def srcdir_root
    @ardir
  end

  def objdir_root
    '.'
  end

  def relpath
    '.'
  end

  #
  # Option Parsing
  #

  def parsearg_global
    valid_task = /\A(?:#{TASKS.map {|task,desc| task }.join '|'})\z/

    while arg = ARGV.shift
      case arg
      when /\A\w+\z/
        raise InstallError, "invalid task: #{arg}" unless valid_task =~ arg
        return arg

      when '-q', '--quiet'
        @options['verbose'] = false

      when       '--verbose'
        @options['verbose'] = true

      when '-h', '--help'
        print_usage $stdout
        exit 0

      when '-v', '--version'
        puts "#{File.basename($0)} version #{Version}"
        exit 0
      
      when '--copyright'
        puts Copyright
        exit 0

      else
        raise InstallError, "unknown global option '#{arg}'"
      end
    end

    raise InstallError, <<EOS
No task or global option given.
Typical installation procedure is:
    $ ruby #{File.basename($0)} config
    $ ruby #{File.basename($0)} setup
    # ruby #{File.basename($0)} install  (may require root privilege)
EOS
  end


  def parsearg_no_options
    raise InstallError, "#{task}:  unknown options: #{ARGV.join ' '}"\
        unless ARGV.empty?
  end

  alias parsearg_show       parsearg_no_options
  alias parsearg_setup      parsearg_no_options
  alias parsearg_clean      parsearg_no_options
  alias parsearg_distclean  parsearg_no_options

  def parsearg_config
    re = /\A--(#{ConfigTable.keys.join '|'})(?:=(.*))?\z/
    @options['config-opt'] = []

    while i = ARGV.shift
      if /\A--?\z/ =~ i
        @options['config-opt'] = ARGV.dup
        break
      end
      m = re.match(i) or raise InstallError, "config: unknown option #{i}"
      name, value = m.to_a[1,2]
      if value
        if ConfigTable.bool_config?(name)
          raise InstallError, "config: --#{name} allows only yes/no for argument"\
              unless /\A(y(es)?|n(o)?|t(rue)?|f(alse))\z/i =~ value
          value = (/\Ay(es)?|\At(rue)/i =~ value) ? 'yes' : 'no'
        end
      else
        raise InstallError, "config: --#{name} requires argument"\
            unless ConfigTable.bool_config?(name)
        value = 'yes'
      end
      @config[name] = value
    end
  end

  def parsearg_install
    @options['no-harm'] = false
    @options['install-prefix'] = ''
    while a = ARGV.shift
      case a
      when /\A--no-harm\z/
        @options['no-harm'] = true
      when /\A--prefix=(.*)\z/
        path = $1
        path = File.expand_path(path) unless path[0,1] == '/'
        @options['install-prefix'] = path
      else
        raise InstallError, "install: unknown option #{a}"
      end
    end
  end

  def print_usage(out)
    out.puts 'Typical Installation Procedure:'
    out.puts "  $ ruby #{File.basename $0} config"
    out.puts "  $ ruby #{File.basename $0} setup"
    out.puts "  # ruby #{File.basename $0} install (may require root privilege)"
    out.puts
    out.puts 'Detailed Usage:'
    out.puts "  ruby #{File.basename $0} <global option>"
    out.puts "  ruby #{File.basename $0} [<global options>] <task> [<task options>]"

    fmt = "  %-20s %s\n"
    out.puts
    out.puts 'Global options:'
    out.printf fmt, '-q,--quiet',   'suppress message outputs'
    out.printf fmt, '   --verbose', 'output messages verbosely'
    out.printf fmt, '-h,--help',    'print this message'
    out.printf fmt, '-v,--version', 'print version and quit'
    out.printf fmt, '   --copyright',  'print copyright and quit'

    out.puts
    out.puts 'Tasks:'
    TASKS.each do |name, desc|
      out.printf "  %-10s  %s\n", name, desc
    end

    out.puts
    out.puts 'Options for config:'
    ConfigTable.each_definition do |name, (default, arg, desc, default2)|
      out.printf "  %-20s %s [%s]\n",
                 '--'+ name + (ConfigTable.bool_config?(name) ? '' : '='+arg),
                 desc,
                 default2 || default
    end
    out.printf "  %-20s %s [%s]\n",
        '--rbconfig=path', 'your rbconfig.rb to load', "running ruby's"

    out.puts
    out.puts 'Options for install:'
    out.printf "  %-20s %s [%s]\n",
        '--no-harm', 'only display what to do if given', 'off'
    out.printf "  %-20s %s [%s]\n",
        '--prefix',  'install path prefix', '$prefix'

    out.puts
  end

  #
  # Task Handlers
  #

  def exec_config
    @installer.exec_config
    @config.save   # must be final
  end

  def exec_setup
    @installer.exec_setup
  end

  def exec_install
    @installer.exec_install
  end

  def exec_show
    ConfigTable.each_name do |k|
      v = @config.get_raw(k)
      if not v or v.empty?
        v = '(not specified)'
      end
      printf "%-10s %s\n", k, v
    end
  end

  def exec_clean
    @installer.exec_clean
  end

  def exec_distclean
    @installer.exec_distclean
  end

end


class ToplevelInstallerMulti < ToplevelInstaller

  include HookUtils
  include HookScriptAPI
  include FileOperations

  def initialize(ardir)
    super
    @packages = all_dirs_in("#{@ardir}/packages")
    raise 'no package exists' if @packages.empty?
  end

  def run_metaconfigs
    eval_file_ifexist "#{@ardir}/metaconfig"
    @packages.each do |name|
      eval_file_ifexist "#{@ardir}/packages/#{name}/metaconfig"
    end
  end

  def init_installers
    @installers = {}
    @packages.each do |pack|
      @installers[pack] = Installer.new(@config, @options,
                                       "#{@ardir}/packages/#{pack}",
                                       "packages/#{pack}")
    end

    with    = extract_selection(config('with'))
    without = extract_selection(config('without'))
    @selected = @installers.keys.select {|name|
                  (with.empty? or with.include?(name)) \
                      and not without.include?(name)
                }
  end

  def extract_selection(list)
    a = list.split(/,/)
    a.each do |name|
      raise InstallError, "no such package: #{name}" \
              unless @installers.key?(name)
    end
    a
  end

  def print_usage(f)
    super
    f.puts 'Inluded packages:'
    f.puts '  ' + @packages.sort.join(' ')
    f.puts
  end

  #
  # multi-package metaconfig API
  #

  attr_reader :packages

  def declare_packages(list)
    raise 'package list is empty' if list.empty?
    list.each do |name|
      raise "directory packages/#{name} does not exist"\
              unless File.dir?("#{@ardir}/packages/#{name}")
    end
    @packages = list
  end

  #
  # Task Handlers
  #

  def exec_config
    run_hook 'pre-config'
    each_selected_installers {|inst| inst.exec_config }
    run_hook 'post-config'
    @config.save   # must be final
  end

  def exec_setup
    run_hook 'pre-setup'
    each_selected_installers {|inst| inst.exec_setup }
    run_hook 'post-setup'
  end

  def exec_install
    run_hook 'pre-install'
    each_selected_installers {|inst| inst.exec_install }
    run_hook 'post-install'
  end

  def exec_clean
    rm_f 'config.save'
    run_hook 'pre-clean'
    each_selected_installers {|inst| inst.exec_clean }
    run_hook 'post-clean'
  end

  def exec_distclean
    rm_f 'config.save'
    run_hook 'pre-distclean'
    each_selected_installers {|inst| inst.exec_distclean }
    run_hook 'post-distclean'
  end

  #
  # lib
  #

  def each_selected_installers
    Dir.mkdir 'packages' unless File.dir?('packages')
    @selected.each do |pack|
      $stderr.puts "Processing the package `#{pack}' ..." if @options['verbose']
      Dir.mkdir "packages/#{pack}" unless File.dir?("packages/#{pack}")
      Dir.chdir "packages/#{pack}"
      yield @installers[pack]
      Dir.chdir '../..'
    end
  end

  def verbose?
    @options['verbose']
  end

  def no_harm?
    @options['no-harm']
  end

end


class Installer

  FILETYPES = %w( bin lib ext data )

  include HookScriptAPI
  include HookUtils
  include FileOperations

  def initialize(config, opt, srcroot, objroot)
    @config = config
    @options = opt
    @srcdir = File.expand_path(srcroot)
    @objdir = File.expand_path(objroot)
    @currdir = '.'
  end

  def inspect
    "#<#{self.class} #{File.basename(@srcdir)}>"
  end

  #
  # Hook Script API bases
  #

  def srcdir_root
    @srcdir
  end

  def objdir_root
    @objdir
  end

  def relpath
    @currdir
  end

  #
  # configs/options
  #

  def no_harm?
    @options['no-harm']
  end

  def verbose?
    @options['verbose']
  end

  def verbose_off
    begin
      save, @options['verbose'] = @options['verbose'], false
      yield
    ensure
      @options['verbose'] = save
    end
  end

  #
  # TASK config
  #

  def exec_config
    exec_task_traverse 'config'
  end

  def config_dir_bin(rel)
  end

  def config_dir_lib(rel)
  end

  def config_dir_ext(rel)
    extconf if extdir?(curr_srcdir())
  end

  def extconf
    opt = @options['config-opt'].join(' ')
    command "#{config('ruby-prog')} #{curr_srcdir()}/extconf.rb #{opt}"
  end

  def config_dir_data(rel)
  end

  #
  # TASK setup
  #

  def exec_setup
    exec_task_traverse 'setup'
  end

  def setup_dir_bin(rel)
    all_files_in(curr_srcdir()).each do |fname|
      adjust_shebang "#{curr_srcdir()}/#{fname}"
    end
  end

  # modify: #!/usr/bin/ruby
  # modify: #! /usr/bin/ruby
  # modify: #!ruby
  # not modify: #!/usr/bin/env ruby
  SHEBANG_RE = /\A\#!\s*\S*ruby\S*/

  def adjust_shebang(path)
    return if no_harm?

    tmpfile = File.basename(path) + '.tmp'
    begin
      File.open(path, 'rb') {|r|
        File.open(tmpfile, 'wb') {|w|
          first = r.gets
          return unless SHEBANG_RE =~ first

          $stderr.puts "adjusting shebang: #{File.basename path}" if verbose?
          w.print first.sub(SHEBANG_RE, '#!' + config('ruby-path'))
          w.write r.read
        }
      }
      move_file tmpfile, File.basename(path)
    ensure
      File.unlink tmpfile if File.exist?(tmpfile)
    end
  end

  def setup_dir_lib(rel)
  end

  def setup_dir_ext(rel)
    make if extdir?(curr_srcdir())
  end

  def setup_dir_data(rel)
  end

  #
  # TASK install
  #

  def exec_install
    exec_task_traverse 'install'
  end

  def install_dir_bin(rel)
    install_files collect_filenames_auto(), "#{config('bin-dir')}/#{rel}", 0755
  end

  def install_dir_lib(rel)
    install_files ruby_scripts(), "#{config('rb-dir')}/#{rel}", 0644
  end

  def install_dir_ext(rel)
    return unless extdir?(curr_srcdir())
    install_files ruby_extentions('.'),
                  "#{config('so-dir')}/#{File.dirname(rel)}",
                  0555
  end

  def install_dir_data(rel)
    install_files collect_filenames_auto(), "#{config('data-dir')}/#{rel}", 0644
  end

  def install_files(list, dest, mode)
    mkdir_p dest, @options['install-prefix']
    list.each do |fname|
      install fname, dest, mode, @options['install-prefix']
    end
  end

  def ruby_scripts
    collect_filenames_auto().select {|n| /\.r(b|html)\z/ =~ n}
  end
  
  # picked up many entries from cvs-1.11.1/src/ignore.c
  reject_patterns = %w( 
    core RCSLOG tags TAGS .make.state
    .nse_depinfo #* .#* cvslog.* ,* .del-* *.olb
    *~ *.old *.bak *.BAK *.orig *.rej _$* *$

    *.org *.in .*
  )
  mapping = {
    '.' => '\.',
    '$' => '\$',
    '#' => '\#',
    '*' => '.*'
  }
  REJECT_PATTERNS = Regexp.new('\A(?:' +
                               reject_patterns.map {|pat|
                                 pat.gsub(/[\.\$\#\*]/) {|ch| mapping[ch] }
                               }.join('|') +
                               ')\z')

  def collect_filenames_auto
    mapdir((existfiles() - hookfiles()).reject {|fname|
             REJECT_PATTERNS =~ fname
           })
  end

  def existfiles
    all_files_in(curr_srcdir()) | all_files_in('.')
  end

  def hookfiles
    %w( pre-%s post-%s pre-%s.rb post-%s.rb ).map {|fmt|
      %w( config setup install clean ).map {|t| sprintf(fmt, t) }
    }.flatten
  end

  def mapdir(filelist)
    filelist.map {|fname|
      if File.exist?(fname)   # objdir
        fname
      else                    # srcdir
        File.join(curr_srcdir(), fname)
      end
    }
  end

  def ruby_extentions(dir)
    _ruby_extentions(dir) or
        raise InstallError, "no ruby extention exists: 'ruby #{$0} setup' first"
  end

  DLEXT = /\.#{ ::Config::CONFIG['DLEXT'] }\z/

  def _ruby_extentions(dir)
    Dir.open(dir) {|d|
      return d.select {|fname| DLEXT =~ fname }
    }
  end

  #
  # TASK clean
  #

  def exec_clean
    exec_task_traverse 'clean'
    rm_f 'config.save'
    rm_f 'InstalledFiles'
  end

  def clean_dir_bin(rel)
  end

  def clean_dir_lib(rel)
  end

  def clean_dir_ext(rel)
    return unless extdir?(curr_srcdir())
    make 'clean' if File.file?('Makefile')
  end

  def clean_dir_data(rel)
  end

  #
  # TASK distclean
  #

  def exec_distclean
    exec_task_traverse 'distclean'
    rm_f 'config.save'
    rm_f 'InstalledFiles'
  end

  def distclean_dir_bin(rel)
  end

  def distclean_dir_lib(rel)
  end

  def distclean_dir_ext(rel)
    return unless extdir?(curr_srcdir())
    make 'distclean' if File.file?('Makefile')
  end

  #
  # lib
  #

  def exec_task_traverse(task)
    run_hook "pre-#{task}"
    FILETYPES.each do |type|
      if config('without-ext') == 'yes' and type == 'ext'
        $stderr.puts 'skipping ext/* by user option' if verbose?
        next
      end
      traverse task, type, "#{task}_dir_#{type}"
    end
    run_hook "post-#{task}"
  end

  def traverse(task, rel, mid)
    dive_into(rel) {
      run_hook "pre-#{task}"
      __send__ mid, rel.sub(%r[\A.*?(?:/|\z)], '')
      all_dirs_in(curr_srcdir()).each do |d|
        traverse task, "#{rel}/#{d}", mid
      end
      run_hook "post-#{task}"
    }
  end

  def dive_into(rel)
    return unless File.dir?("#{@srcdir}/#{rel}")

    dir = File.basename(rel)
    Dir.mkdir dir unless File.dir?(dir)
    prevdir = Dir.pwd
    Dir.chdir dir
    $stderr.puts '---> ' + rel if verbose?
    @currdir = rel
    yield
    Dir.chdir prevdir
    $stderr.puts '<--- ' + rel if verbose?
    @currdir = File.dirname(rel)
  end

end


if $0 == __FILE__
  begin
    if multipackage_install?
      ToplevelInstallerMulti.invoke
    else
      ToplevelInstaller.invoke
    end
  rescue
    raise if $DEBUG
    $stderr.puts $!.message
    $stderr.puts "Try 'ruby #{$0} --help' for detailed usage."
    exit 1
  end
end
