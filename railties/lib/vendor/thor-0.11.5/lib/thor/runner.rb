require 'fileutils'
require 'open-uri'
require 'yaml'
require 'digest/md5'
require 'pathname'

class Thor::Runner < Thor #:nodoc:
  map "-T" => :list, "-i" => :install, "-u" => :update

  # Override Thor#help so it can give information about any class and any method.
  #
  def help(meth=nil)
    if meth && !self.respond_to?(meth)
      initialize_thorfiles(meth)
      klass, task = Thor::Util.namespace_to_thor_class_and_task(meth)
      # Send mapping -h because it works with Thor::Group too
      klass.start(["-h", task].compact, :shell => self.shell)
    else
      super
    end
  end

  # If a task is not found on Thor::Runner, method missing is invoked and
  # Thor::Runner is then responsable for finding the task in all classes.
  #
  def method_missing(meth, *args)
    meth = meth.to_s
    initialize_thorfiles(meth)
    klass, task = Thor::Util.namespace_to_thor_class_and_task(meth)
    args.unshift(task) if task
    klass.start(args, :shell => shell)
  end

  desc "install NAME", "Install an optionally named Thor file into your system tasks"
  method_options :as => :string, :relative => :boolean
  def install(name)
    initialize_thorfiles

    # If a directory name is provided as the argument, look for a 'main.thor' 
    # task in said directory.
    begin
      if File.directory?(File.expand_path(name))
        base, package = File.join(name, "main.thor"), :directory
        contents      = open(base).read
      else
        base, package = name, :file
        contents      = open(name).read
      end
    rescue OpenURI::HTTPError
      raise Error, "Error opening URI '#{name}'"
    rescue Errno::ENOENT
      raise Error, "Error opening file '#{name}'"
    end

    say "Your Thorfile contains:"
    say contents

    return false if no?("Do you wish to continue [y/N]?")

    as = options["as"] || begin
      first_line = contents.split("\n")[0]
      (match = first_line.match(/\s*#\s*module:\s*([^\n]*)/)) ? match[1].strip : nil
    end

    unless as
      basename = File.basename(name)
      as = ask("Please specify a name for #{name} in the system repository [#{basename}]:")
      as = basename if as.empty?
    end

    location = if options[:relative] || name =~ /^http:\/\//
      name
    else
      File.expand_path(name)
    end

    thor_yaml[as] = {
      :filename   => Digest::MD5.hexdigest(name + as),
      :location   => location,
      :namespaces => Thor::Util.namespaces_in_content(contents, base)
    }

    save_yaml(thor_yaml)
    say "Storing thor file in your system repository"
    destination = File.join(thor_root, thor_yaml[as][:filename])

    if package == :file
      File.open(destination, "w") { |f| f.puts contents }
    else
      FileUtils.cp_r(name, destination)
    end

    thor_yaml[as][:filename] # Indicate success
  end

  desc "uninstall NAME", "Uninstall a named Thor module"
  def uninstall(name)
    raise Error, "Can't find module '#{name}'" unless thor_yaml[name]
    say "Uninstalling #{name}."
    FileUtils.rm_rf(File.join(thor_root, "#{thor_yaml[name][:filename]}"))

    thor_yaml.delete(name)
    save_yaml(thor_yaml)

    puts "Done."
  end

  desc "update NAME", "Update a Thor file from its original location"
  def update(name)
    raise Error, "Can't find module '#{name}'" if !thor_yaml[name] || !thor_yaml[name][:location]

    say "Updating '#{name}' from #{thor_yaml[name][:location]}"

    old_filename = thor_yaml[name][:filename]
    self.options = self.options.merge("as" => name)
    filename     = install(thor_yaml[name][:location])

    unless filename == old_filename
      File.delete(File.join(thor_root, old_filename))
    end
  end

  desc "installed", "List the installed Thor modules and tasks"
  method_options :internal => :boolean
  def installed
    initialize_thorfiles(nil, true)

    klasses = Thor::Base.subclasses
    klasses -= [Thor, Thor::Runner] unless options["internal"]

    display_klasses(true, klasses)
  end

  desc "list [SEARCH]", "List the available thor tasks (--substring means .*SEARCH)"
  method_options :substring => :boolean, :group => :string, :all => :boolean
  def list(search="")
    initialize_thorfiles

    search = ".*#{search}" if options["substring"]
    search = /^#{search}.*/i
    group  = options[:group] || "standard"

    klasses = Thor::Base.subclasses.select do |k|
      (options[:all] || k.group == group) && k.namespace =~ search
    end

    display_klasses(false, klasses)
  end

  private

    def thor_root
      Thor::Util.thor_root
    end

    def thor_yaml
      @thor_yaml ||= begin
        yaml_file = File.join(thor_root, "thor.yml")
        yaml      = YAML.load_file(yaml_file) if File.exists?(yaml_file)
        yaml || {}
      end
    end

    # Save the yaml file. If none exists in thor root, creates one.
    #
    def save_yaml(yaml)
      yaml_file = File.join(thor_root, "thor.yml")

      unless File.exists?(yaml_file)
        FileUtils.mkdir_p(thor_root)
        yaml_file = File.join(thor_root, "thor.yml")
        FileUtils.touch(yaml_file)
      end

      File.open(yaml_file, "w") { |f| f.puts yaml.to_yaml }
    end

    # Load the thorfiles. If relevant_to is supplied, looks for specific files
    # in the thor_root instead of loading them all.
    #
    # By default, it also traverses the current path until find Thor files, as
    # described in thorfiles. This look up can be skipped by suppliying
    # skip_lookup true.
    #
    def initialize_thorfiles(relevant_to=nil, skip_lookup=false)
      thorfiles(relevant_to, skip_lookup).each do |f|
        Thor::Util.load_thorfile(f) unless Thor::Base.subclass_files.keys.include?(File.expand_path(f))
      end
    end

    # Finds Thorfiles by traversing from your current directory down to the root
    # directory of your system. If at any time we find a Thor file, we stop.
    #
    # We also ensure that system-wide Thorfiles are loaded first, so local
    # Thorfiles can override them.
    #
    # ==== Example
    #
    # If we start at /Users/wycats/dev/thor ...
    #
    # 1. /Users/wycats/dev/thor
    # 2. /Users/wycats/dev
    # 3. /Users/wycats <-- we find a Thorfile here, so we stop
    #
    # Suppose we start at c:\Documents and Settings\james\dev\thor ...
    #
    # 1. c:\Documents and Settings\james\dev\thor
    # 2. c:\Documents and Settings\james\dev
    # 3. c:\Documents and Settings\james
    # 4. c:\Documents and Settings
    # 5. c:\ <-- no Thorfiles found!
    #
    def thorfiles(relevant_to=nil, skip_lookup=false)
      # Deal with deprecated thor when :namespaces: is available as constants
      save_yaml(thor_yaml) if Thor::Util.convert_constants_to_namespaces(thor_yaml)

      thorfiles = []

      unless skip_lookup
        Pathname.pwd.ascend do |path|
          thorfiles = Thor::Util.globs_for(path).map { |g| Dir[g] }.flatten
          break unless thorfiles.empty?
        end
      end

      files  = (relevant_to ? thorfiles_relevant_to(relevant_to) : Thor::Util.thor_root_glob)
      files += thorfiles
      files -= ["#{thor_root}/thor.yml"]

      files.map! do |file|
        File.directory?(file) ? File.join(file, "main.thor") : file
      end
    end

    # Load thorfiles relevant to the given method. If you provide "foo:bar" it
    # will load all thor files in the thor.yaml that has "foo" e "foo:bar"
    # namespaces registered.
    #
    def thorfiles_relevant_to(meth)
      lookup = [ meth, meth.split(":")[0...-1].join(":") ]

      files = thor_yaml.select do |k, v|
        v[:namespaces] && !(v[:namespaces] & lookup).empty?
      end

      files.map { |k, v| File.join(thor_root, "#{v[:filename]}") }
    end

    # Display information about the given klasses. If with_module is given,
    # it shows a table with information extracted from the yaml file.
    #
    def display_klasses(with_modules=false, klasses=Thor.subclasses)
      klasses -= [Thor, Thor::Runner] unless with_modules
      raise Error, "No Thor tasks available" if klasses.empty?

      if with_modules && !thor_yaml.empty?
        info  = []
        labels = ["Modules", "Namespaces"]

        info << labels
        info << [ "-" * labels[0].size, "-" * labels[1].size ]

        thor_yaml.each do |name, hash|
          info << [ name, hash[:namespaces].join(", ") ]
        end

        print_table info
        say ""
      end

      unless klasses.empty?
        klasses.dup.each do |klass|
          klasses -= Thor::Util.thor_classes_in(klass)
        end

        klasses.each { |k| display_tasks(k) }
      else
        say "\033[1;34mNo Thor tasks available\033[0m"
      end
    end

    # Display tasks from the given Thor class.
    #
    def display_tasks(klass)
      unless klass.tasks.empty?
        base = klass.namespace

        color = base == "default" ? :magenta : :blue
        say shell.set_color(base, color, true)
        say "-" * base.length

        klass.help(shell, :short => true, :ident => 0, :namespace => true)
      end
    end
end
