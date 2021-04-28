# frozen_string_literal: true

module ActionView
  class TemplatePath
    attr_reader :name, :prefix, :partial, :virtual
    alias_method :partial?, :partial
    alias_method :virtual_path, :virtual

    def self.virtual(name, prefix, partial)
      if prefix.empty?
        "#{partial ? "_" : ""}#{name}"
      elsif partial
        "#{prefix}/_#{name}"
      else
        "#{prefix}/#{name}"
      end
    end

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

    def self.build(name, prefix, partial)
      new name, prefix, partial, virtual(name, prefix, partial)
    end

    def initialize(name, prefix, partial, virtual)
      @name    = name
      @prefix  = prefix
      @partial = partial
      @virtual = virtual
    end

    def to_str
      @virtual
    end
    alias :to_s :to_str
  end
end
