module ActionController #:nodoc:
  module Session #:nodoc:
    def self.append_features(base) #:nodoc:
      super #:nodoc:
      base.after_filter(:clear_persistant_model_associations)
    end

    private
      def clear_persistant_model_associations #:doc:
        session = @session.instance_variable_get("@data")
        session.each { |key, obj| obj.clear_association_cache if obj.respond_to?(:clear_association_cache) } if session
      end
  end
end