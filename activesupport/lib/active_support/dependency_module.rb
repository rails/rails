module ActiveSupport
  module DependencyModule
    def append_features(base)
      return false if base < self
      (@_dependencies ||= []).each { |dep| base.send(:include, dep) }
      super
    end

    def depends_on(*mods)
      mods.each do |mod|
        next if self < mod
        @_dependencies ||= []
        @_dependencies << mod
      end
    end
  end
end
