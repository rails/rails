require "abstract_unit"
require "active_support/core_ext/digest/uuid"

class DigestUUIDExt < ActiveSupport::TestCase
  def test_v3_uuids
    assert_equal "3d813cbb-47fb-32ba-91df-831e1593ac29", Digest::UUID.uuid_v3(Digest::UUID::DNS_NAMESPACE, "www.widgets.com")
    assert_equal "86df55fb-428e-3843-8583-ba3c05f290bc", Digest::UUID.uuid_v3(Digest::UUID::URL_NAMESPACE, "http://www.widgets.com")
    assert_equal "8c29ab0e-a2dc-3482-b5eb-20cb2e2387a1", Digest::UUID.uuid_v3(Digest::UUID::OID_NAMESPACE, "1.2.3")
    assert_equal "ee49149d-53a4-304a-890b-468229f6afc3", Digest::UUID.uuid_v3(Digest::UUID::X500_NAMESPACE, "cn=John Doe, ou=People, o=Acme, Inc., c=US")
  end

  def test_v5_uuids
    assert_equal "21f7f8de-8051-5b89-8680-0195ef798b6a", Digest::UUID.uuid_v5(Digest::UUID::DNS_NAMESPACE, "www.widgets.com")
    assert_equal "4e570fd8-186d-5a74-90f0-4d28e34673a1", Digest::UUID.uuid_v5(Digest::UUID::URL_NAMESPACE, "http://www.widgets.com")
    assert_equal "42d5e23b-3a02-5135-85c6-52d1102f1f00", Digest::UUID.uuid_v5(Digest::UUID::OID_NAMESPACE, "1.2.3")
    assert_equal "fd5b2ddf-bcfe-58b6-90d6-db50f74db527", Digest::UUID.uuid_v5(Digest::UUID::X500_NAMESPACE, "cn=John Doe, ou=People, o=Acme, Inc., c=US")
  end

  def test_invalid_hash_class
    assert_raise ArgumentError do
      Digest::UUID.uuid_from_hash(Digest::SHA2, Digest::UUID::OID_NAMESPACE, "1.2.3")
    end
  end
end
