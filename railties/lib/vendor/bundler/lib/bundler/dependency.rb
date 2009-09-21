module Bundler
  class InvalidEnvironmentName < StandardError; end

  class Dependency
    attr_reader :name, :version, :require_as, :only, :except

    def initialize(name, options = {}, &block)
      options.each do |k, v|
        options[k.to_s] = v
      end

      @name       = name
      @version    = options["version"] || ">= 0"
      @require_as = Array(options["require_as"] || name)
      @only       = options["only"]
      @except     = options["except"]
      @block      = block

      if (@only && @only.include?("rubygems")) || (@except && @except.include?("rubygems"))
        raise InvalidEnvironmentName, "'rubygems' is not a valid environment name"
      end
    end

    def in?(environment)
      environment = environment.to_s

      return false unless !@only || @only.include?(environment)
      return false if @except && @except.include?(environment)
      true
    end

    def to_s
      to_gem_dependency.to_s
    end

    def require(environment)
      return unless in?(environment)

      @require_as.each do |file|
        super(file)
      end

      @block.call if @block
    end

    def to_gem_dependency
      @gem_dep ||= Gem::Dependency.new(name, version)
    end

    def ==(o)
      [name, version, require_as, only, except] ==
        [o.name, o.version, o.require_as, o.only, o.except]
    end

  end
end
