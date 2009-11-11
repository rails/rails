require 'rake'

class Thor
  # Adds a compatibility layer to your Thor classes which allows you to use
  # rake package tasks. For example, to use rspec rake tasks, one can do:
  #
  #   require 'thor/rake_compat'
  #
  #   class Default < Thor
  #     include Thor::RakeCompat
  #
  #     Spec::Rake::SpecTask.new(:spec) do |t|
  #       t.spec_opts = ['--options', "spec/spec.opts"]
  #       t.spec_files = FileList['spec/**/*_spec.rb']
  #     end
  #   end
  #
  module RakeCompat
    def self.rake_classes
      @rake_classes ||= []
    end

    def self.included(base)
      # Hack. Make rakefile point to invoker, so rdoc task is generated properly.
      rakefile = File.basename(caller[0].match(/(.*):\d+/)[1])
      Rake.application.instance_variable_set(:@rakefile, rakefile)
      self.rake_classes << base
    end
  end
end

class Object #:nodoc:
  alias :rake_task :task
  alias :rake_namespace :namespace

  def task(*args, &block)
    task = rake_task(*args, &block)

    if klass = Thor::RakeCompat.rake_classes.last
      non_namespaced_name = task.name.split(':').last

      description = non_namespaced_name
      description << task.arg_names.map{ |n| n.to_s.upcase }.join(' ')
      description.strip!

      klass.desc description, task.comment || non_namespaced_name
      klass.send :define_method, non_namespaced_name do |*args|
        Rake::Task[task.name.to_sym].invoke(*args)
      end
    end

    task
  end

  def namespace(name, &block)
    if klass = Thor::RakeCompat.rake_classes.last
      const_name = Thor::Util.camel_case(name.to_s).to_sym
      klass.const_set(const_name, Class.new(Thor))
      new_klass = klass.const_get(const_name)
      Thor::RakeCompat.rake_classes << new_klass
    end

    rake_namespace(name, &block)
    Thor::RakeCompat.rake_classes.pop
  end
end
