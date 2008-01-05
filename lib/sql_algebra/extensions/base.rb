class ActiveRecord::Base
  def self.bring_forth(record, includes = [])
    object = cache.get(record % klass.primary_key) { Klass.instantiate(record % Klass.attributes) }
    includes.each do |include|
      case include
      when Symbol
        object.send(association = include).bring_forth(record)
      when Hash
        include.each do |association, nested_associations|
          object.send(association).bring_forth(record, nested_associations)
        end
      end
    end
  end
end