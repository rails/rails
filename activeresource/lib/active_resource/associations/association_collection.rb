module ActiveResource
  module Associations

    class AssociationCollection < Array

      def initialize(array, host_resource, association_col)
        @host_resource   = host_resource
        @association_col = association_col
        self.concat array
      end

      def <<(member)
        member.send "#{@association_col}=", @host_resource.id
        member.save
        super(member)
      end

      def delete(member)
        member.send "#{@association_col}=", nil
        member.save
        super(member)
      end

      def clear
        self.each{|member| delete(member)}
        super
      end

    end
  end
end
