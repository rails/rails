module ActiveRecord
  class Base
    class << self
      # This method is deprecated in favor of find with the :conditions option.
      #
      # Works like find, but the record matching +id+ must also meet the +conditions+.
      # +RecordNotFound+ is raised if no record can be found matching the +id+ or meeting the condition.
      # Example:
      #   Person.find_on_conditions 5, "first_name LIKE '%dav%' AND last_name = 'heinemeier'"
      def find_on_conditions(ids, conditions) # :nodoc:
        find(ids, :conditions => conditions)
      end
      deprecate :find_on_conditions => "use find(ids, :conditions => conditions)"

      # This method is deprecated in favor of find(:first, options).
      #
      # Returns the object for the first record responding to the conditions in +conditions+, 
      # such as "group = 'master'". If more than one record is returned from the query, it's the first that'll
      # be used to create the object. In such cases, it might be beneficial to also specify 
      # +orderings+, like "income DESC, name", to control exactly which record is to be used. Example: 
      #   Employee.find_first "income > 50000", "income DESC, name"
      def find_first(conditions = nil, orderings = nil, joins = nil) # :nodoc:
        find(:first, :conditions => conditions, :order => orderings, :joins => joins)
      end
      deprecate :find_first => "use find(:first, ...)"

      # This method is deprecated in favor of find(:all, options).
      #
      # Returns an array of all the objects that could be instantiated from the associated
      # table in the database. The +conditions+ can be used to narrow the selection of objects (WHERE-part),
      # such as by "color = 'red'", and arrangement of the selection can be done through +orderings+ (ORDER BY-part),
      # such as by "last_name, first_name DESC". A maximum of returned objects and their offset can be specified in 
      # +limit+ with either just a single integer as the limit or as an array with the first element as the limit, 
      # the second as the offset. Examples:
      #   Project.find_all "category = 'accounts'", "last_accessed DESC", 15
      #   Project.find_all ["category = ?", category_name], "created ASC", [15, 20]
      def find_all(conditions = nil, orderings = nil, limit = nil, joins = nil) # :nodoc:
        limit, offset = limit.is_a?(Array) ? limit : [ limit, nil ]
        find(:all, :conditions => conditions, :order => orderings, :joins => joins, :limit => limit, :offset => offset)
      end
      deprecate :find_all => "use find(:all, ...)"
    end
  end
end
