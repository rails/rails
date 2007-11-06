unless Enumerable.method_defined?(:map)
  module Enumerable
    alias map collect
  end
end

unless Enumerable.method_defined?(:select)
  module Enumerable
    alias select find_all
  end
end

unless Enumerable.method_defined?(:reject)
  module Enumerable
    def reject
      result = []
      each do |i|
        result.push i unless yield(i)
      end
      result
    end
  end
end

unless Enumerable.method_defined?(:sort_by)
  module Enumerable
    def sort_by
      map {|i| [yield(i), i] }.sort.map {|val, i| i }
    end
  end
end

unless File.respond_to?(:read)
  def File.read(fname)
    File.open(fname) {|f|
      return f.read
    }
  end
end
