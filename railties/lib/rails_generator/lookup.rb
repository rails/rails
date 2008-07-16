require 'pathname'

require File.dirname(__FILE__) + '/spec'

class Object
  class << self
    # Lookup missing generators using const_missing.  This allows any
    # generator to reference another without having to know its location:
    # RubyGems, ~/.rails/generators, and RAILS_ROOT/generators.
    def lookup_missing_generator(class_id)
      if md = /(.+)Generator$/.match(class_id.to_s)
        name = md.captures.first.demodulize.underscore
        Rails::Generator::Base.lookup(name).klass
      else
        const_missing_before_generators(class_id)
      end
    end

    unless respond_to?(:const_missing_before_generators)
      alias_method :const_missing_before_generators, :const_missing
      alias_method :const_missing, :lookup_missing_generator
    end
  end
end

# User home directory lookup adapted from RubyGems.
def Dir.user_home
  if ENV['HOME']
    ENV['HOME']
  elsif ENV['USERPROFILE']
    ENV['USERPROFILE']
  elsif ENV['HOMEDRIVE'] and ENV['HOMEPATH']
    "#{ENV['HOMEDRIVE']}:#{ENV['HOMEPATH']}"
  else
    File.expand_path '~'
  end
end


module Rails
  module Generator

    # Generator lookup is managed by a list of sources which return specs
    # describing where to find and how to create generators.  This module
    # provides class methods for manipulating the source list and looking up
    # generator specs, and an #instance wrapper for quickly instantiating
    # generators by name.
    #
    # A spec is not a generator:  it's a description of where to find
    # the generator and how to create it.  A source is anything that
    # yields generators from #each.  PathSource and GemGeneratorSource are provided.
    module Lookup
      def self.included(base)
        base.extend(ClassMethods)
        base.use_component_sources!
      end

      # Convenience method to instantiate another generator.
      def instance(generator_name, args, runtime_options = {})
        self.class.instance(generator_name, args, runtime_options)
      end

      module ClassMethods
        # The list of sources where we look, in order, for generators.
        def sources
          read_inheritable_attribute(:sources) or use_component_sources!
        end

        # Add a source to the end of the list.
        def append_sources(*args)
          sources.concat(args.flatten)
          invalidate_cache!
        end

        # Add a source to the beginning of the list.
        def prepend_sources(*args)
          write_inheritable_array(:sources, args.flatten + sources)
          invalidate_cache!
        end

        # Reset the source list.
        def reset_sources
          write_inheritable_attribute(:sources, [])
          invalidate_cache!
        end

        # Use application generators (app, ?).
        def use_application_sources!
          reset_sources
          sources << PathSource.new(:builtin, "#{File.dirname(__FILE__)}/generators/applications")
        end

        # Use component generators (model, controller, etc).
        # 1.  Rails application.  If RAILS_ROOT is defined we know we're
        #     generating in the context of a Rails application, so search
        #     RAILS_ROOT/generators.
        # 2.  Look in plugins, either for generators/ or rails_generators/ 
        #     directories within each plugin
        # 3.  User home directory.  Search ~/.rails/generators.
        # 4.  RubyGems.  Search for gems named *_generator, and look for 
        #     generators within any RubyGem's 
        #     /rails_generators/<generator_name>_generator.rb file.
        # 5.  Builtins.  Model, controller, mailer, scaffold, and so on.
        def use_component_sources!
          reset_sources
          if defined? ::RAILS_ROOT
            sources << PathSource.new(:lib, "#{::RAILS_ROOT}/lib/generators")
            sources << PathSource.new(:vendor, "#{::RAILS_ROOT}/vendor/generators")
            Rails.configuration.plugin_paths.each do |path|
              relative_path = Pathname.new(File.expand_path(path)).relative_path_from(Pathname.new(::RAILS_ROOT))
              sources << PathSource.new(:"plugins (#{relative_path})", "#{path}/*/**/{,rails_}generators")
            end
          end
          sources << PathSource.new(:user, "#{Dir.user_home}/.rails/generators")
          if Object.const_defined?(:Gem)
            sources << GemGeneratorSource.new
            sources << GemPathSource.new
          end
          sources << PathSource.new(:builtin, "#{File.dirname(__FILE__)}/generators/components")
        end

        # Lookup knows how to find generators' Specs from a list of Sources.
        # Searches the sources, in order, for the first matching name.
        def lookup(generator_name)
          @found ||= {}
          generator_name = generator_name.to_s.downcase
          @found[generator_name] ||= cache.find { |spec| spec.name == generator_name }
          unless @found[generator_name] 
            chars = generator_name.scan(/./).map{|c|"#{c}.*?"}
            rx = /^#{chars}$/
            gns = cache.select{|spec| spec.name =~ rx }
            @found[generator_name] ||= gns.first if gns.length == 1
            raise GeneratorError, "Pattern '#{generator_name}' matches more than one generator: #{gns.map{|sp|sp.name}.join(', ')}" if gns.length > 1
          end
          @found[generator_name] or raise GeneratorError, "Couldn't find '#{generator_name}' generator"
        end

        # Convenience method to lookup and instantiate a generator.
        def instance(generator_name, args = [], runtime_options = {})
          lookup(generator_name).klass.new(args, full_options(runtime_options))
        end

        private
          # Lookup and cache every generator from the source list.
          def cache
            @cache ||= sources.inject([]) { |cache, source| cache + source.to_a }
          end

          # Clear the cache whenever the source list changes.
          def invalidate_cache!
            @cache = nil
          end
      end
    end

    # Sources enumerate (yield from #each) generator specs which describe
    # where to find and how to create generators.  Enumerable is mixed in so,
    # for example, source.collect will retrieve every generator.
    # Sources may be assigned a label to distinguish them.
    class Source
      include Enumerable

      attr_reader :label
      def initialize(label)
        @label = label
      end

      # The each method must be implemented in subclasses.
      # The base implementation raises an error.
      def each
        raise NotImplementedError
      end

      # Return a convenient sorted list of all generator names.
      def names
        map { |spec| spec.name }.sort
      end
    end


    # PathSource looks for generators in a filesystem directory.
    class PathSource < Source
      attr_reader :path

      def initialize(label, path)
        super label
        @path = path
      end

      # Yield each eligible subdirectory.
      def each
        Dir["#{path}/[a-z]*"].each do |dir|
          if File.directory?(dir)
            yield Spec.new(File.basename(dir), dir, label)
          end
        end
      end
    end

    class AbstractGemSource < Source
      def initialize
        super :RubyGems
      end
    end

    # GemGeneratorSource hits the mines to quarry for generators.  The latest versions
    # of gems named *_generator are selected.
    class GemGeneratorSource < AbstractGemSource
      # Yield latest versions of generator gems.
      def each
        Gem::cache.search(/_generator$/).inject({}) { |latest, gem|
          hem = latest[gem.name]
          latest[gem.name] = gem if hem.nil? or gem.version > hem.version
          latest
        }.values.each { |gem|
          yield Spec.new(gem.name.sub(/_generator$/, ''), gem.full_gem_path, label)
        }
      end
    end

    # GemPathSource looks for generators within any RubyGem's /rails_generators/<generator_name>_generator.rb file.
    class GemPathSource < AbstractGemSource
      # Yield each generator within rails_generator subdirectories.
      def each
        generator_full_paths.each do |generator|
          yield Spec.new(File.basename(generator).sub(/_generator.rb$/, ''), File.dirname(generator), label)
        end
      end

      private
        def generator_full_paths
          @generator_full_paths ||=
            Gem::cache.inject({}) do |latest, name_gem|
              name, gem = name_gem
              hem = latest[gem.name]
              latest[gem.name] = gem if hem.nil? or gem.version > hem.version
              latest
            end.values.inject([]) do |mem, gem|
              Dir[gem.full_gem_path + '/{rails_,}generators/**/*_generator.rb'].each do |generator|
                mem << generator
              end
              mem
            end
        end
    end

  end
end
