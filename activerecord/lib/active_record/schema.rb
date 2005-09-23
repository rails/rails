module ActiveRecord

  class Schema < Migration #:nodoc:
    private_class_method :new

    def self.define(info={}, &block)
      instance_eval(&block)

      unless info.empty?
        initialize_schema_information
        cols = columns('schema_info')

        info = info.map do |k,v|
          v = quote(v, cols.detect { |c| c.name == k.to_s })
          "#{k} = #{v}"
        end

        update "UPDATE schema_info SET #{info.join(", ")}"
      end
    end
  end

end
