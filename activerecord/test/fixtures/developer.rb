class Developer < ActiveRecord::Base
  has_and_belongs_to_many :projects

  protected
    def validate
      errors.add_on_boundary_breaking("name", 3..20)
    end
end
