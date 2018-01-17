# frozen_string_literal: true

require "cases/helper"

class EagerSingularizationTest < ActiveRecord::TestCase
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
    has_many :analyses, dependent: :destroy
    has_many :successes, through: :analyses
    has_many :dresses, dependent: :destroy
    has_many :compresses, through: :dresses
  end

  class Analysis < ActiveRecord::Base
    belongs_to :crisis
    belongs_to :success
  end

  class Success < ActiveRecord::Base
    has_many :analyses, dependent: :destroy
    has_many :crises, through: :analyses
  end

  class Dress < ActiveRecord::Base
    belongs_to :crisis
    has_many :compresses
  end

  class Compress < ActiveRecord::Base
    belongs_to :dress
  end

  def setup
    connection.create_table :viri do |t|
      t.column :octopus_id, :integer
      t.column :species, :string
    end
    connection.create_table :octopi do |t|
      t.column :species, :string
    end
    connection.create_table :passes do |t|
      t.column :bus_id, :integer
      t.column :rides, :integer
    end
    connection.create_table :buses do |t|
      t.column :name, :string
    end
    connection.create_table :crises_messes, id: false do |t|
      t.column :crisis_id, :integer
      t.column :mess_id, :integer
    end
    connection.create_table :messes do |t|
      t.column :name, :string
    end
    connection.create_table :crises do |t|
      t.column :name, :string
    end
    connection.create_table :successes do |t|
      t.column :name, :string
    end
    connection.create_table :analyses do |t|
      t.column :crisis_id, :integer
      t.column :success_id, :integer
    end
    connection.create_table :dresses do |t|
      t.column :crisis_id, :integer
    end
    connection.create_table :compresses do |t|
      t.column :dress_id, :integer
    end
  end

  teardown do
    connection.drop_table :viri
    connection.drop_table :octopi
    connection.drop_table :passes
    connection.drop_table :buses
    connection.drop_table :crises_messes
    connection.drop_table :messes
    connection.drop_table :crises
    connection.drop_table :successes
    connection.drop_table :analyses
    connection.drop_table :dresses
    connection.drop_table :compresses
  end

  def test_eager_no_extra_singularization_belongs_to
    assert_nothing_raised do
      Virus.all.merge!(includes: :octopus).to_a
    end
  end

  def test_eager_no_extra_singularization_has_one
    assert_nothing_raised do
      Octopus.all.merge!(includes: :virus).to_a
    end
  end

  def test_eager_no_extra_singularization_has_many
    assert_nothing_raised do
      Bus.all.merge!(includes: :passes).to_a
    end
  end

  def test_eager_no_extra_singularization_has_and_belongs_to_many
    assert_nothing_raised do
      Crisis.all.merge!(includes: :messes).to_a
      Mess.all.merge!(includes: :crises).to_a
    end
  end

  def test_eager_no_extra_singularization_has_many_through_belongs_to
    assert_nothing_raised do
      Crisis.all.merge!(includes: :successes).to_a
    end
  end

  def test_eager_no_extra_singularization_has_many_through_has_many
    assert_nothing_raised do
      Crisis.all.merge!(includes: :compresses).to_a
    end
  end

  private
    def connection
      ActiveRecord::Base.connection
    end
end
