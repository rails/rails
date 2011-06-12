class SecurePerson < ActiveRecord::Base
  belongs_to :parent, :class_name => "SecurePerson"

  before_save :encrypt_name

  private

  def encrypt_name
    self.name = name.reverse
  end

  def self.create_relation
    EncryptedRelation.new(self, arel_table)
  end
end

class EncryptedRelation < ActiveRecord::Relation
  def build_where(opts, *args)
    opts[:name] = opts[:name].reverse if opts[:name]
    super
  end
end
