module ActionView #:nodoc:
  # = Action View PathSet
  class PathSet < Array #:nodoc:
    %w(initialize << concat insert push unshift).each do |method|
      class_eval <<-METHOD, __FILE__, __LINE__ + 1
        def #{method}(*args)
          super
          typecast!
        end
      METHOD
    end

    def find(*args)
      template = find_all(*args).first
      template or raise MissingTemplate.new(self, "{#{args[1].join(',')},}/#{args[0]}", args[3], args[2])
    end

    def find_all(path, prefixes = [], *args)
      templates = []
      prefixes.each do |prefix|
        each do |resolver|
          templates << resolver.find_all(path, prefix, *args)
        end
        # return templates unless templates.flatten!.empty? XXX this was original behavior; turns this method into find_some, but probably makes it faster
      end
      templates.flatten
    end

    def exists?(*args)
      find_all(*args).any?
    end

  protected

    def typecast!
      each_with_index do |path, i|
        path = path.to_s if path.is_a?(Pathname)
        next unless path.is_a?(String)
        self[i] = FileSystemResolver.new(path)
      end
    end
  end
end
