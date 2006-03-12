module Mime
  class Type < String
    def initialize(string, part_of_all = true)
      @part_of_all = part_of_all
      super(string)
    end
    
    def to_sym
      SYMBOLIZED_MIME_TYPES[self] ? SYMBOLIZED_MIME_TYPES[self] : to_sym
    end

    def ===(list)
      if list.is_a?(Array)
        list.include?(self)
      else
        super
      end
    end
  end

  SYMBOLIZED_MIME_TYPES = {
    ""                         => :unspecified,
    "*/*"                      => :all,
    "text/html"                => :html,
    "application/javascript"   => :js,
    "application/x-javascript" => :js,
    "text/javascript"          => :js,
    "text/xml"                 => :xml,
    "application/xml"          => :xml,
    "application/rss+xml"      => :rss,
    "application/rss+atom"     => :atom,
    "application/x-xml"        => :xml,
    "application/x-yaml"       => :yaml
  }

  ALL        = Type.new "*/*"
  HTML       = Type.new "text/html"
  JS         = Type.new "text/javascript"
  JAVASCRIPT = Type.new "text/javascript"
  XML        = Type.new "application/xml"
  RSS        = Type.new "application/rss+xml"
  ATOM       = Type.new "application/atom+xml"
  YAML       = Type.new "application/x-yaml"
end