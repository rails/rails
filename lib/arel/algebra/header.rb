module Arel
  class Header
    include Enumerable

    def initialize(attrs = [])
      @attributes = attrs.to_ary
      @names = Hash.new do |h,k|
        h[k] = @attributes.detect { |a| a.named?(k) }
      end
    end

    def each(&block)
      to_ary.each(&block)
      self
    end

    def [](key)
      case key
      when String, Symbol then find_by_name(key)
      when Attribute      then find_by_attribute(key)
      end
    end

    def ==(other)
      to_set == other.to_set
    end

    def union(other)
      new(to_ary | other)
    end

    alias | union

    def to_ary
      @attributes
    end

    def bind(relation)
      Header.new(map { |a| a.bind(relation) })
    end

    # TMP
    def index(i)
      to_ary.index(i)
    end

  private

    def new(attrs)
      self.class.new(attrs)
    end

    def matching(attribute)
      select { |a| !a.is_a?(Value) && a.root == attribute.root }
    end

    def find_by_name(name)
      @names[name.to_sym]
    end

    def find_by_attribute(attr)
      matching(attr).max do |a, b|
        (a.original_attribute / attr) <=> (b.original_attribute / attr)
      end
    end
  end
end
