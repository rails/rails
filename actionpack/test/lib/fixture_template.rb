module ActionView #:nodoc:
  class FixtureResolver < Resolver
    def initialize(hash = {}, options = {})
      super(options)
      @hash = hash
    end
    
    def find_templates(name, details, prefix, partial)
      if regexp = details_to_regexp(name, details, prefix, partial)
        cached(regexp) do
          templates = []
          @hash.select { |k,v| k =~ regexp }.each do |path, source|
            templates << Template.new(source, path, *path_to_details(path))
          end
          templates.sort_by {|t| -t.details.values.compact.size }
        end
      end
    end
    
  private
  
    def formats_regexp
      @formats_regexp ||= begin
        formats = Mime::SET.symbols
        '(?:' + formats.map { |l| "\\.#{Regexp.escape(l.to_s)}" }.join('|') + ')?'
      end
    end
    
    def handler_regexp
      e = TemplateHandlers.extensions.map{|h| "\\.#{Regexp.escape(h.to_s)}"}.join("|")
      "(?:#{e})?"
    end
  
    def details_to_regexp(name, details, prefix, partial)
      path = ""
      path << "#{prefix}/" unless prefix.empty?
      path << (partial ? "_#{name}" : name)
    
      extensions = ""
      [:locales, :formats].each do |k|
        extensions << if exts = details[k]
          '(?:' + exts.map {|e| "\\.#{Regexp.escape(e.to_s)}"}.join('|') + ')?'
        else
          k == :formats ? formats_regexp : ''
        end
      end

      %r'^#{Regexp.escape(path)}#{extensions}#{handler_regexp}$'
    end
    
    # TODO: fix me
    # :api: plugin
    def path_to_details(path)
      # [:erb, :format => :html, :locale => :en, :partial => true/false]
      if m = path.match(%r'(_)?[\w-]+((?:\.[\w-]+)*)\.(\w+)$')
        partial = m[1] == '_'
        details = (m[2]||"").split('.').reject { |e| e.empty? }
        handler = Template.handler_class_for_extension(m[3])
    
        format  = Mime[details.last] && details.pop.to_sym
        locale  = details.last && details.pop.to_sym
        
        return handler, :format => format, :locale => locale, :partial => partial
      end
    end
  end
end