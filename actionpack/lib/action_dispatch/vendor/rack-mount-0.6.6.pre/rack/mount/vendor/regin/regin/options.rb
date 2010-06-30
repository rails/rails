module Regin
  class Options
    def self.from_int(flags)
      multiline  = flags & Regexp::MULTILINE != 0
      ignorecase = flags & Regexp::IGNORECASE != 0
      extended   = flags & Regexp::EXTENDED != 0

      new(multiline, ignorecase, extended)
    end

    attr_reader :multiline, :ignorecase, :extended

    def initialize(*args)
      if args.first.is_a?(Hash)
        @multiline  = args[0][:multiline]
        @ignorecase = args[0][:ignorecase]
        @extended   = args[0][:extended]
      else
        @multiline  = args[0]
        @ignorecase = args[1]
        @extended   = args[2]
      end
    end

    def any?(explicit = false)
      if explicit
        !multiline.nil? || !ignorecase.nil? || !extended.nil?
      else
        multiline || ignorecase || extended
      end
    end

    def to_h(explicit = false)
      if explicit
        options = {}
        options[:multiline]  = multiline  unless multiline.nil?
        options[:ignorecase] = ignorecase unless ignorecase.nil?
        options[:extended]   = extended   unless extended.nil?
        options
      else
        { :multiline => multiline,
          :ignorecase => ignorecase,
          :extended => extended }
      end
    end

    def to_i
      flag = 0
      flag |= Regexp::MULTILINE if multiline
      flag |= Regexp::IGNORECASE if ignorecase
      flag |= Regexp::EXTENDED if extended
      flag
    end
  end
end
