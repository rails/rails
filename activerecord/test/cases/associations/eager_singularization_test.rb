require "cases/helper"

class Virus < ActiveRecord::Base
  belongs_to :octopus
end
class Octopus < ActiveRecord::Base
  has_one :virus
end
class Pass < ActiveRecord::Base
  belongs_to :bus
end
class Bus < ActiveRecord::Base
  has_many :passes
end
class Mess < ActiveRecord::Base
  has_and_belongs_to_many :crises
end
class Crisis < ActiveRecord::Base
  has_and_belongs_to_many :messes
  has_many :analyses, :dependent => :destroy
  has_many :successes, :through => :analyses
  has_many :dresses, :dependent => :destroy
  has_many :compresses, :through => :dresses
end
class Analysis < ActiveRecord::Base
  belongs_to :crisis
  belongs_to :success
end
class Success < ActiveRecord::Base
  has_many :analyses, :dependent => :destroy
  has_many :crises, :through => :analyses
end
class Dress < ActiveRecord::Base
  belongs_to :crisis
  has_many :compresses
end
class Compress < ActiveRecord::Base
  belongs_to :dress
end


class EagerSingularizationTest < ActiveRecord::TestCase

  def setup
    if ActiveRecord::Base.connection.supports_migrations?
      ActiveRecord::Base.connection.create_table :viri do |t|
        t.column :octopus_id, :integer
        t.column :species, :string
      end
      ActiveRecord::Base.connection.create_table :octopi do |t|
        t.column :species, :string
      end
      ActiveRecord::Base.connection.create_table :passes do |t|
        t.column :bus_id, :integer
        t.column :rides, :integer
      end
      ActiveRecord::Base.connection.create_table :buses do |t|
        t.column :name, :string
      end
      ActiveRecord::Base.connection.create_table :crises_messes, :id => false do |t|
        t.column :crisis_id, :integer
        t.column :mess_id, :integer
      end
      ActiveRecord::Base.connection.create_table :messes do |t|
        t.column :name, :string
      end
      ActiveRecord::Base.connection.create_table :crises do |t|
        t.column :name, :string
      end
      ActiveRecord::Base.connection.create_table :successes do |t|
        t.column :name, :string
      end
      ActiveRecord::Base.connection.create_table :analyses do |t|
        t.column :crisis_id, :integer
        t.column :success_id, :integer
      end
      ActiveRecord::Base.connection.create_table :dresses do |t|
        t.column :crisis_id, :integer
      end
      ActiveRecord::Base.connection.create_table :compresses do |t|
        t.column :dress_id, :integer
      end
      @have_tables = true
    else
      @have_tables = false
    end
  end

  def teardown
    ActiveRecord::Base.connection.drop_table :viri
    ActiveRecord::Base.connection.drop_table :octopi
    ActiveRecord::Base.connection.drop_table :passes
    ActiveRecord::Base.connection.drop_table :buses
    ActiveRecord::Base.connection.drop_table :crises_messes
    ActiveRecord::Base.connection.drop_table :messes
    ActiveRecord::Base.connection.drop_table :crises
    ActiveRecord::Base.connection.drop_table :successes
    ActiveRecord::Base.connection.drop_table :analyses
    ActiveRecord::Base.connection.drop_table :dresses
    ActiveRecord::Base.connection.drop_table :compresses
  end

  def test_eager_no_extra_singularization_belongs_to
    return unless @have_tables
    assert_nothing_raised do
      Virus.find(:all, :include => :octopus)
    end
  end

  def test_eager_no_extra_singularization_has_one
    return unless @have_tables
    assert_nothing_raised do
      Octopus.find(:all, :include => :virus)
    end
  end

  def test_eager_no_extra_singularization_has_many
    return unless @have_tables
    assert_nothing_raised do
      Bus.find(:all, :include => :passes)
    end
  end

  def test_eager_no_extra_singularization_has_and_belongs_to_many
    return unless @have_tables
    assert_nothing_raised do
      Crisis.find(:all, :include => :messes)
      Mess.find(:all, :include => :crises)
    end
  end

  def test_eager_no_extra_singularization_has_many_through_belongs_to
    return unless @have_tables
    assert_nothing_raised do
      Crisis.find(:all, :include => :successes)
    end
  end

  def test_eager_no_extra_singularization_has_many_through_has_many
    return unless @have_tables
    assert_nothing_raised do
      Crisis.find(:all, :include => :compresses)
    end
  end
end
