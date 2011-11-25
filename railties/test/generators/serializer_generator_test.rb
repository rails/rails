require 'generators/generators_test_helper'
require 'rails/generators/rails/serializer/serializer_generator'

class SerializerGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  arguments %w(account name:string description:text business:references)

  def test_generates_a_serializer
    run_generator
    assert_file "app/serializers/account_serializer.rb", /class AccountSerializer < ActiveModel::Serializer/
  end

  def test_generates_a_namespaced_serializer
    run_generator ["admin/account"]
    assert_file "app/serializers/admin/account_serializer.rb", /class Admin::AccountSerializer < ActiveModel::Serializer/
  end

  def test_uses_application_serializer_if_one_exists
    Object.const_set(:ApplicationSerializer, Class.new)
    run_generator
    assert_file "app/serializers/account_serializer.rb", /class AccountSerializer < ApplicationSerializer/
  ensure
    Object.send :remove_const, :ApplicationSerializer
  end

  def test_uses_namespace_application_serializer_if_one_exists
    Object.const_set(:SerializerNamespace, Module.new)
    SerializerNamespace.const_set(:ApplicationSerializer, Class.new)
    Rails::Generators.namespace = SerializerNamespace
    run_generator
    assert_file "app/serializers/serializer_namespace/account_serializer.rb",
      /module SerializerNamespace\n  class AccountSerializer < ApplicationSerializer/
  ensure
    Object.send :remove_const, :SerializerNamespace
    Rails::Generators.namespace = nil
  end

  def test_uses_given_parent
    Object.const_set(:ApplicationSerializer, Class.new)
    run_generator ["Account", "--parent=MySerializer"]
    assert_file "app/serializers/account_serializer.rb", /class AccountSerializer < MySerializer/
  ensure
    Object.send :remove_const, :ApplicationSerializer
  end

  def test_generates_attributes_and_associations
    run_generator
    assert_file "app/serializers/account_serializer.rb" do |serializer|
      assert_match(/^  attributes :name, :description$/, serializer)
      assert_match(/^  has_one :business$/, serializer)
    end
  end

  def test_with_no_attributes_does_not_add_extra_space
    run_generator ["account"]
    assert_file "app/serializers/account_serializer.rb", /class AccountSerializer < ActiveModel::Serializer\nend/
  end

  def test_invokes_default_test_framework
    run_generator
    assert_file "test/unit/account_serializer_test.rb", /class AccountSerializerTest < ActiveSupport::TestCase/
  end
end
