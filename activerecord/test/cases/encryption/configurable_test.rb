require "cases/encryption/helper"
require "models/book"

class ActiveRecord::ConfigurableTest < ActiveRecord::TestCase
  test 'can access context properties with top level getters' do
    assert_equal ActiveRecord::Encryption.key_provider, ActiveRecord::Encryption.context.key_provider
  end

  test "can add listeners that will get invoked when declaring encrypted attributes" do
    @klass, @attribute_name = nil
    ActiveRecord::Encryption.on_encrypted_attribute_declared do |declared_klass, declared_attribute_name|
      @klass = declared_klass
      @attribute_name = declared_attribute_name
    end

    klass = Class.new(EncryptedBook) do
      self.table_name = "books"
      encrypt_attribute :isbn
    end

    assert_equal klass, @klass
    assert_equal :isbn, @attribute_name
  end

  test "install autofiltered params" do
    application = OpenStruct.new(config: OpenStruct.new(filter_parameters: []))
    ActiveRecord::Encryption.install_auto_filtered_parameters(application)

    Class.new(EncryptedBook) do
      self.table_name = "books"
      encrypt_attribute :isbn
    end

    assert_includes application.config.filter_parameters, :isbn
  end
end
