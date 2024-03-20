# frozen_string_literal: true

require "cases/helper"
require "models/developer"
require "models/company"
require "models/computer"
require "models/comment"
require "models/contract"
require "models/mentor"
require "models/post"

class AutomaticPreloadingTest < ActiveRecord::TestCase
  fixtures :developers, :companies, :posts

  def test_models_are_marked_as_automatically_preloading
    developers = Developer.order(:id).limit(2).automatic_preloading.to_a
    developers.each do |developer|
      assert developer.automatic_preloading?
    end
  end

  def test_automatic_preloading_by_default
    with_automatic_preloading_by_default(ActiveRecord::Base) do
      developers = Developer.order(:id).limit(2).to_a
      developers.each do |developer|
        assert developer.automatic_preloading?
      end
    end
  end

  def test_collection_associations_are_automatically_loaded
    Developer.order(:id).limit(2).all.each do |developer|
      Contract.create!(developer_id: developer.id)
    end

    developers = Developer.order(:id).limit(2).automatic_preloading.to_a

    developers.each do |developer|
      assert_not developer.association(:contracts).loaded?
    end

    assert_queries(1) do
      developers.each do |developer|
        developer.contracts.load
      end
    end

    developers.each do |developer|
      assert developer.association(:contracts).loaded?
    end
  end

  def test_has_one_association_is_automatically_loaded
    Developer.order(:id).limit(2).each do |developer|
      developer.update!(mentor: Mentor.create!)
    end

    developers = Developer.order(:id).limit(2).automatic_preloading.to_a

    developers.each do |developer|
      assert_not developer.association(:mentor).loaded?
    end

    assert_queries(1) do
      developers.each do |developer|
        developer.mentor
      end
    end

    developers.each do |developer|
      assert developer.association(:mentor).loaded?
    end
  end

  def test_chained_associations_are_automatically_loaded
    companies = [companies(:first_client), companies(:first_firm)]
    Developer.order(:id).limit(2).all.each_with_index do |developer, i|
      Contract.create!(developer_id: developer.id, company: companies[i])
    end

    developers = Developer.order(:id).limit(2).automatic_preloading.to_a

    developers.first.contracts.to_a
    developers.each do |developer|
      assert_not developer.contracts.first.association(:company).loaded?
    end

    assert_queries(1) do
      developers.each do |developer|
        developer.contracts.first.company
      end
    end

    developers.each do |developer|
      assert developer.contracts.first.association(:company).loaded?
    end
  end

  def test_cannot_automatically_load_scoped_associations
    Developer.order(:id).limit(2).all.each do |developer|
      Comment.create!(developer_id: developer.id, body: "I'm #{developer.name}", post: posts(:welcome))
    end

    developers = Developer.limit(2).automatic_preloading.to_a

    developers.each do |developer|
      assert_not developer.association(:comments).loaded?
    end

    assert_queries(2) do
      developers.each do |developer|
        developer.comments.load
      end
    end

    developers.each do |developer|
      assert developer.association(:comments).loaded?
    end
  end

  private
    def with_automatic_preloading_by_default(model)
      previous_automatic_preloading_by_default = model.automatic_preloading_by_default

      model.automatic_preloading_by_default = true

      yield
    ensure
      model.automatic_preloading_by_default = previous_automatic_preloading_by_default
    end
end
