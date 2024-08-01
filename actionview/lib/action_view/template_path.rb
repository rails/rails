# frozen_string_literal: true

module ActionView
  # = Action View \TemplatePath
  #
  # Represents a template path within ActionView's lookup and rendering system,
  # like "users/show"
  #
  # TemplatePath makes it convenient to convert between separate name, prefix,
  # partial arguments and the virtual path.
  class TemplatePath
    attr_reader :name, :prefix, :partial, :virtual
    alias_method :partial?, :partial
    alias_method :virtual_path, :virtual

    # Convert name, prefix, and partial into a virtual path string
    def self.virtual(name, prefix, partial)
      if prefix.empty?
        "#{partial ? "_" : ""}#{name}"
      elsif partial
        "#{prefix}/_#{name}"
      else
        "#{prefix}/#{name}"
      end
    end

    # Build a TemplatePath form a virtual path
    def self.parse(virtual)
      if nameidx = virtual.rindex("/")
        prefix = virtual[0, nameidx]
        name = virtual.from(nameidx + 1)
        prefix = prefix[1..] if prefix.start_with?("/")
      else
        prefix = ""
        name = virtual
      end
      partial = name.start_with?("_")
      name = name[1..] if partial
      new name, prefix, partial, virtual
    end

    # Convert name, prefix, and partial into a TemplatePath
    def self.build(name, prefix, partial)
      new name, prefix, partial, virtual(name, prefix, partial)
    end

    def initialize(name, prefix, partial, virtual)
      @name    = name
      @prefix  = prefix
      @partial = partial
      @virtual = virtual
    end

    alias :to_str :virtual
    alias :to_s :virtual

    def hash # :nodoc:
      @virtual.hash
    end

    def eql?(other) # :nodoc:
      @virtual == other.virtual
    end
    alias :== :eql? # :nodoc:
  end
end
