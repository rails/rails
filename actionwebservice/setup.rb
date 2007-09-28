#
# setup.rb
#
# Copyright (c) 2000-2004 Minero Aoki
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# Note: Originally licensed under LGPL v2+. Using MIT license for Rails
# with permission of Minero Aoki.

#

unless Enumerable.method_defined?(:map)   # Ruby 1.4.6
  module Enumerable
    alias map collect
  end
end

unless File.respond_to?(:read)   # Ruby 1.6
  def File.read(fname)
    open(fname) {|f|
      return f.read
    }
  end
end

def File.binread(fname)
  open(fname, 'rb') {|f|
    return f.read
  }
end

# for corrupted windows stat(2)
def File.dir?(path)
  File.directory?((path[-1,1] == '/') ? path : path + '/')
end


class SetupError < StandardError; end

def setup_rb_error(msg)
  raise SetupError, msg
end

#
# Config
#

if arg = ARGV.detect {|arg| /\A--rbconfig=/ =~ arg }
  ARGV.delete(arg)
  require arg.split(/=/, 2)[1]
  $".push 'rbconfig.rb'
else
  require 'rbconfig'
end

def multipackage_install?
  FileTest.directory?(File.dirname($0) + '/packages')
end


class ConfigItem
  def initialize(name, template, default, desc)
    @name = name.freeze
    @template = template
    @value = default
    @default = default.dup.freeze
    @description = desc
  end

  attr_reader :name
  attr_reader :description

  attr_accessor :default
  alias help_default default

  def help_opt
    "--#{@name}=#{@template}"
  end

  def value
    @value
  end

  def eval(table)
    @value.gsub(%r<\$([^/]+)>) { table[$1] }
  end

  def set(val)
    @value = check(val)
  end

  private

  def check(val)
    setup_rb_error "config: --#{name} requires argument" unless val
    val
  end
end

class BoolItem < ConfigItem
  def config_type
    'bool'
  end

  def help_opt
    "--#{@name}"
  end

  private

  def check(val)
    return 'yes' unless val
    unless /\A(y(es)?|n(o)?|t(rue)?|f(alse))\z/i =~ val
      setup_rb_error "config: --#{@name} accepts only yes/no for argument"
    end
    (/\Ay(es)?|\At(rue)/i =~ value) ? 'yes' : 'no'
  end
end

class PathItem < ConfigItem
  def config_type
    'path'
  end

  private

  def check(path)
    setup_rb_error "config: --#{@name} requires argument"  unless path
    path[0,1] == '$' ? path : File.expand_path(path)
  end
end

class ProgramItem < ConfigItem
  def config_type
    'program'
  end
end

class SelectItem < ConfigItem
  def initialize(name, template, default, desc)
    super
    @ok = template.split('/')
  end

  def config_type
    'select'
  end

  private

  def check(val)
    unless @ok.include?(val.strip)
      setup_rb_error "config: use --#{@name}=#{@template} (#{val})"
    end
    val.strip
  end
end

class PackageSelectionItem < ConfigItem
  def initialize(name, template, default, help_default, desc)
    super name, template, default, desc
    @help_default = help_default
  end

  attr_reader :help_default

  def config_type
    'package'
  end

  private

  def check(val)
    unless File.dir?("packages/#{val}")
      setup_rb_error "config: no such package: #{val}"
    end
    val
  end
end

class ConfigTable_class

  def initialize(items)
    @items = items
    @table = {}
    items.each do |i|
      @table[i.name] = i
    end
    ALIASES.each do |ali, name|
      @table[ali] = @table[name]
    end
  end

  include Enumerable

  def each(&block)
    @items.each(&block)
  end

  def key?(name)
    @table.key?(name)
  end

  def lookup(name)
    @table[name] or raise ArgumentError, "no such config item: #{name}"
  end

  def add(item)
    @items.push item
    @table[item.name] = item
  end

  def remove(name)
    item = lookup(name)
    @items.delete_if {|i| i.name == name }
    @table.delete_if {|name, i| i.name == name }
    item
  end

  def new
    dup()
  end

  def savefile
    '.config'
  end

  def load
    begin
      t = dup()
      File.foreach(savefile()) do |line|
        k, v = *line.split(/=/, 2)
        t[k] = v.strip
      end
      t
    rescue Errno::ENOENT
      setup_rb_error $!.message + "#{File.basename($0)} config first"
    end
  end

  def save
    @items.each {|i| i.value }
    File.open(savefile(), 'w') {|f|
      @items.each do |i|
        f.printf "%s=%s\n", i.name, i.value if i.value
      end
    }
  end

  def [](key)
    lookup(key).eval(self)
  end

  def []=(key, val)
    lookup(key).set val
  end

end

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

if c['rubylibdir']
  # V < 1.6.3
  _stdruby         = c['rubylibdir']
  _siteruby        = c['sitedir']
  _siterubyver     = c['sitelibdir']
  _siterubyverarch = c['sitearchdir']
elsif newpath_p
  # 1.4.4 <= V <= 1.6.3
  _stdruby         = "$prefix/lib/ruby/#{version}"
  _siteruby        = c['sitedir']
  _siterubyver     = "$siteruby/#{version}"
  _siterubyverarch = "$siterubyver/#{c['arch']}"
else
  # V < 1.4.4
  _stdruby         = "$prefix/lib/ruby/#{version}"
  _siteruby        = "$prefix/lib/ruby/#{version}/site_ruby"
  _siterubyver     = _siteruby
  _siterubyverarch = "$siterubyver/#{c['arch']}"
end
libdir = '-* dummy libdir *-'
stdruby = '-* dummy rubylibdir *-'
siteruby = '-* dummy site_ruby *-'
siterubyver = '-* dummy site_ruby version *-'
parameterize = lambda {|path|
  path.sub(/\A#{Regexp.quote(c['prefix'])}/, '$prefix')\
      .sub(/\A#{Regexp.quote(libdir)}/,      '$libdir')\
      .sub(/\A#{Regexp.quote(stdruby)}/,     '$stdruby')\
      .sub(/\A#{Regexp.quote(siteruby)}/,    '$siteruby')\
      .sub(/\A#{Regexp.quote(siterubyver)}/, '$siterubyver')
}
libdir          = parameterize.call(c['libdir'])
stdruby         = parameterize.call(_stdruby)
siteruby        = parameterize.call(_siteruby)
siterubyver     = parameterize.call(_siterubyver)
siterubyverarch = parameterize.call(_siterubyverarch)

if arg = c['configure_args'].split.detect {|arg| /--with-make-prog=/ =~ arg }
  makeprog = arg.sub(/'/, '').split(/=/, 2)[1]
else
  makeprog = 'make'
end

common_conf = [
  PathItem.new('prefix', 'path', c['prefix'],
               'path prefix of target environment'),
  PathItem.new('bindir', 'path', parameterize.call(c['bindir']),
               'the directory for commands'),
  PathItem.new('libdir', 'path', libdir,
               'the directory for libraries'),
  PathItem.new('datadir', 'path', parameterize.call(c['datadir']),
               'the directory for shared data'),
  PathItem.new('mandir', 'path', parameterize.call(c['mandir']),
               'the directory for man pages'),
  PathItem.new('sysconfdir', 'path', parameterize.call(c['sysconfdir']),
               'the directory for man pages'),
  PathItem.new('stdruby', 'path', stdruby,
               'the directory for standard ruby libraries'),
  PathItem.new('siteruby', 'path', siteruby,
      'the directory for version-independent aux ruby libraries'),
  PathItem.new('siterubyver', 'path', siterubyver,
               'the directory for aux ruby libraries'),
  PathItem.new('siterubyverarch', 'path', siterubyverarch,
               'the directory for aux ruby binaries'),
  PathItem.new('rbdir', 'path', '$siterubyver',
               'the directory for ruby scripts'),
  PathItem.new('sodir', 'path', '$siterubyverarch',
               'the directory for ruby extentions'),
  PathItem.new('rubypath', 'path', rubypath,
               'the path to set to #! line'),
  ProgramItem.new('rubyprog', 'name', rubypath,
                  'the ruby program using for installation'),
  ProgramItem.new('makeprog', 'name', makeprog,
                  'the make program to compile ruby extentions'),
  SelectItem.new('shebang', 'all/ruby/never', 'ruby',
                 'shebang line (#!) editing mode'),
  BoolItem.new('without-ext', 'yes/no', 'no',
               'does not compile/install ruby extentions')
]
class ConfigTable_class   # open again
  ALIASES = {
    'std-ruby'         => 'stdruby',
    'site-ruby-common' => 'siteruby',     # For backward compatibility
    'site-ruby'        => 'siterubyver',  # For backward compatibility
    'bin-dir'          => 'bindir',
    'bin-dir'          => 'bindir',
    'rb-dir'           => 'rbdir',
    'so-dir'           => 'sodir',
    'data-dir'         => 'datadir',
    'ruby-path'        => 'rubypath',
    'ruby-prog'        => 'rubyprog',
    'ruby'             => 'rubyprog',
    'make-prog'        => 'makeprog',
    'make'             => 'makeprog'
  }
end
multipackage_conf = [
  PackageSelectionItem.new('with', 'name,name...', '', 'ALL',
                           'package names that you want to install'),
  PackageSelectionItem.new('without', 'name,name...', '', 'NONE',
                           'package names that you do not want to install')
]
if multipackage_install?
  ConfigTable = ConfigTable_class.new(common_conf + multipackage_conf)
else
  ConfigTable = ConfigTable_class.new(common_conf)
end


module MetaConfigAPI

  def eval_file_ifexist(fname)
    instance_eval File.read(fname), fname, 1 if File.file?(fname)
  end

  def config_names
    ConfigTable.map {|i| i.name }
  end

  def config?(name)
    ConfigTable.key?(name)
  end

  def bool_config?(name)
    ConfigTable.lookup(name).config_type == 'bool'
  end

  def path_config?(name)
    ConfigTable.lookup(name).config_type == 'path'
  end

  def value_config?(name)
    case ConfigTable.lookup(name).config_type
    when 'bool', 'path'
      true
    else
      false
    end
  end

  def add_config(item)
    ConfigTable.add item
  end

  def add_bool_config(name, default, desc)
    ConfigTable.add BoolItem.new(name, 'yes/no', default ? 'yes' : 'no', desc)
  end

  def add_path_config(name, default, desc)
    ConfigTable.add PathItem.new(name, 'path', default, desc)
  end

  def set_config_default(name, default)
    ConfigTable.lookup(name).default = default
  end

  def remove_config(name)
    ConfigTable.remove(name)
  end

end


#
# File Operations
#

module FileOperations

  def mkdir_p(dirname, prefix = nil)
    dirname = prefix + File.expand_path(dirname) if prefix
    $stderr.puts "mkdir -p #{dirname}" if verbose?
    return if no_harm?

    # does not check '/'... it's too abnormal case
    dirs = File.expand_path(dirname).split(%r<(?=/)>)
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

    realdest = prefix ? prefix + File.expand_path(dest) : dest
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
    command config('rubyprog') + ' ' + str
  end
  
  def make(task = '')
    command config('makeprog') + ' ' + task
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
      setup_rb_error "hook #{fname} failed:\n" + $!.message
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

  Version   = '3.3.1'
  Copyright = 'Copyright (c) 2000-2004 Minero Aoki'

  TASKS = [
    [ 'all',      'do config, setup, then install' ],
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
    case task = parsearg_global()
    when nil, 'all'
      @config = load_config('config')
      parsearg_config
      init_installers
      exec_config
      exec_setup
      exec_install
    else
      @config = load_config(task)
      __send__ "parsearg_#{task}"
      init_installers
      __send__ "exec_#{task}"
    end
  end
  
  def run_metaconfigs
    eval_file_ifexist "#{@ardir}/metaconfig"
  end

  def load_config(task)
    case task
    when 'config'
      ConfigTable.new
    when 'clean', 'distclean'
      if File.exist?(ConfigTable.savefile)
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
        setup_rb_error "invalid task: #{arg}" unless valid_task =~ arg
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
        setup_rb_error "unknown global option '#{arg}'"
      end
    end

    nil
  end


  def parsearg_no_options
    unless ARGV.empty?
      setup_rb_error "#{task}:  unknown options: #{ARGV.join ' '}"
    end
  end

  alias parsearg_show       parsearg_no_options
  alias parsearg_setup      parsearg_no_options
  alias parsearg_clean      parsearg_no_options
  alias parsearg_distclean  parsearg_no_options

  def parsearg_config
    re = /\A--(#{ConfigTable.map {|i| i.name }.join('|')})(?:=(.*))?\z/
    @options['config-opt'] = []

    while i = ARGV.shift
      if /\A--?\z/ =~ i
        @options['config-opt'] = ARGV.dup
        break
      end
      m = re.match(i)  or setup_rb_error "config: unknown option #{i}"
      name, value = *m.to_a[1,2]
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
        setup_rb_error "install: unknown option #{a}"
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

    fmt = "  %-24s %s\n"
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
      out.printf fmt, name, desc
    end

    fmt = "  %-24s %s [%s]\n"
    out.puts
    out.puts 'Options for CONFIG or ALL:'
    ConfigTable.each do |item|
      out.printf fmt, item.help_opt, item.description, item.help_default
    end
    out.printf fmt, '--rbconfig=path', 'rbconfig.rb to load',"running ruby's"
    out.puts
    out.puts 'Options for INSTALL:'
    out.printf fmt, '--no-harm', 'only display what to do if given', 'off'
    out.printf fmt, '--prefix=path',  'install path prefix', '$prefix'
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
    ConfigTable.each do |i|
      printf "%-20s %s\n", i.name, i.value
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
      setup_rb_error "no such package: #{name}"  unless @installers.key?(name)
    end
    a
  end

  def print_usage(f)
    super
    f.puts 'Included packages:'
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
    rm_f ConfigTable.savefile
    run_hook 'pre-clean'
    each_selected_installers {|inst| inst.exec_clean }
    run_hook 'post-clean'
  end

  def exec_distclean
    rm_f ConfigTable.savefile
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
  # Hook Script API base methods
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
    command "#{config('rubyprog')} #{curr_srcdir()}/extconf.rb #{opt}"
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

  def adjust_shebang(path)
    return if no_harm?
    tmpfile = File.basename(path) + '.tmp'
    begin
      File.open(path, 'rb') {|r|
        first = r.gets
        return unless File.basename(config('rubypath')) == 'ruby'
        return unless File.basename(first.sub(/\A\#!/, '').split[0]) == 'ruby'
        $stderr.puts "adjusting shebang: #{File.basename(path)}" if verbose?
        File.open(tmpfile, 'wb') {|w|
          w.print first.sub(/\A\#!\s*\S+/, '#! ' + config('rubypath'))
          w.write r.read
        }
        move_file tmpfile, File.basename(path)
      }
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
    rm_f 'InstalledFiles'
    exec_task_traverse 'install'
  end

  def install_dir_bin(rel)
    install_files collect_filenames_auto(), "#{config('bindir')}/#{rel}", 0755
  end

  def install_dir_lib(rel)
    install_files ruby_scripts(), "#{config('rbdir')}/#{rel}", 0644
  end

  def install_dir_ext(rel)
    return unless extdir?(curr_srcdir())
    install_files ruby_extentions('.'),
                  "#{config('sodir')}/#{File.dirname(rel)}",
                  0555
  end

  def install_dir_data(rel)
    install_files collect_filenames_auto(), "#{config('datadir')}/#{rel}", 0644
  end

  def install_files(list, dest, mode)
    mkdir_p dest, @options['install-prefix']
    list.each do |fname|
      install fname, dest, mode, @options['install-prefix']
    end
  end

  def ruby_scripts
    collect_filenames_auto().select {|n| /\.rb\z/ =~ n }
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
    Dir.open(dir) {|d|
      ents = d.select {|fname| /\.#{::Config::CONFIG['DLEXT']}\z/ =~ fname }
      if ents.empty?
        setup_rb_error "no ruby extention exists: 'ruby #{$0} setup' first"
      end
      return ents
    }
  end

  #
  # TASK clean
  #

  def exec_clean
    exec_task_traverse 'clean'
    rm_f ConfigTable.savefile
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
    rm_f ConfigTable.savefile
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
  rescue SetupError
    raise if $DEBUG
    $stderr.puts $!.message
    $stderr.puts "Try 'ruby #{$0} --help' for detailed usage."
    exit 1
  end
end
