module Arel
  module PathnameExtensions
    def /(path)
      (self + path).expand_path
    end
    
    Pathname.send(:include, self)
  end
end