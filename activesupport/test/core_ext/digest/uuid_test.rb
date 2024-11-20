# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/core_ext/digest"

class DigestUUIDExt < ActiveSupport::TestCase
  def test_constants
    assert_equal "6ba7b810-9dad-11d1-80b4-00c04fd430c8", "%08x-%04x-%04x-%04x-%04x%08x" % Digest::UUID::DNS_NAMESPACE.unpack("NnnnnN")
    assert_equal "6ba7b811-9dad-11d1-80b4-00c04fd430c8", "%08x-%04x-%04x-%04x-%04x%08x" % Digest::UUID::URL_NAMESPACE.unpack("NnnnnN")
    assert_equal "6ba7b812-9dad-11d1-80b4-00c04fd430c8", "%08x-%04x-%04x-%04x-%04x%08x" % Digest::UUID::OID_NAMESPACE.unpack("NnnnnN")
    assert_equal "6ba7b814-9dad-11d1-80b4-00c04fd430c8", "%08x-%04x-%04x-%04x-%04x%08x" % Digest::UUID::X500_NAMESPACE.unpack("NnnnnN")
  end

  def test_v3_uuids_with_rfc4122_namespaced_uuids_enabled
    assert_equal "3d813cbb-47fb-32ba-91df-831e1593ac29", Digest::UUID.uuid_v3("6BA7B810-9DAD-11D1-80B4-00C04FD430C8", "www.widgets.com")
    assert_equal "3d813cbb-47fb-32ba-91df-831e1593ac29", Digest::UUID.uuid_v3("6ba7b810-9dad-11d1-80b4-00c04fd430c8", "www.widgets.com")
    assert_equal "3d813cbb-47fb-32ba-91df-831e1593ac29", Digest::UUID.uuid_v3(Digest::UUID::DNS_NAMESPACE, "www.widgets.com")

    assert_equal "86df55fb-428e-3843-8583-ba3c05f290bc", Digest::UUID.uuid_v3("6BA7B811-9DAD-11D1-80B4-00C04FD430C8", "http://www.widgets.com")
    assert_equal "86df55fb-428e-3843-8583-ba3c05f290bc", Digest::UUID.uuid_v3("6ba7b811-9dad-11d1-80b4-00c04fd430c8", "http://www.widgets.com")
    assert_equal "86df55fb-428e-3843-8583-ba3c05f290bc", Digest::UUID.uuid_v3(Digest::UUID::URL_NAMESPACE, "http://www.widgets.com")

    assert_equal "8c29ab0e-a2dc-3482-b5eb-20cb2e2387a1", Digest::UUID.uuid_v3("6BA7B812-9DAD-11D1-80B4-00C04FD430C8", "1.2.3")
    assert_equal "8c29ab0e-a2dc-3482-b5eb-20cb2e2387a1", Digest::UUID.uuid_v3("6ba7b812-9dad-11d1-80b4-00c04fd430c8", "1.2.3")
    assert_equal "8c29ab0e-a2dc-3482-b5eb-20cb2e2387a1", Digest::UUID.uuid_v3(Digest::UUID::OID_NAMESPACE, "1.2.3")

    assert_equal "ee49149d-53a4-304a-890b-468229f6afc3", Digest::UUID.uuid_v3("6BA7B814-9DAD-11D1-80B4-00C04FD430C8", "cn=John Doe, ou=People, o=Acme, Inc., c=US")
    assert_equal "ee49149d-53a4-304a-890b-468229f6afc3", Digest::UUID.uuid_v3("6ba7b814-9dad-11d1-80b4-00c04fd430c8", "cn=John Doe, ou=People, o=Acme, Inc., c=US")
    assert_equal "ee49149d-53a4-304a-890b-468229f6afc3", Digest::UUID.uuid_v3(Digest::UUID::X500_NAMESPACE, "cn=John Doe, ou=People, o=Acme, Inc., c=US")

    assert_raise ArgumentError do
      Digest::UUID.uuid_v3("A non-UUID string", "some value")
    end
  end

  def test_v5_uuids_with_rfc4122_namespaced_uuids_enabled
    assert_equal "21f7f8de-8051-5b89-8680-0195ef798b6a", Digest::UUID.uuid_v5("6BA7B810-9DAD-11D1-80B4-00C04FD430C8", "www.widgets.com")
    assert_equal "21f7f8de-8051-5b89-8680-0195ef798b6a", Digest::UUID.uuid_v5("6ba7b810-9dad-11d1-80b4-00c04fd430c8", "www.widgets.com")
    assert_equal "21f7f8de-8051-5b89-8680-0195ef798b6a", Digest::UUID.uuid_v5(Digest::UUID::DNS_NAMESPACE, "www.widgets.com")

    assert_equal "4e570fd8-186d-5a74-90f0-4d28e34673a1", Digest::UUID.uuid_v5("6BA7B811-9DAD-11D1-80B4-00C04FD430C8", "http://www.widgets.com")
    assert_equal "4e570fd8-186d-5a74-90f0-4d28e34673a1", Digest::UUID.uuid_v5("6ba7b811-9dad-11d1-80b4-00c04fd430c8", "http://www.widgets.com")
    assert_equal "4e570fd8-186d-5a74-90f0-4d28e34673a1", Digest::UUID.uuid_v5(Digest::UUID::URL_NAMESPACE, "http://www.widgets.com")

    assert_equal "42d5e23b-3a02-5135-85c6-52d1102f1f00", Digest::UUID.uuid_v5("6BA7B812-9DAD-11D1-80B4-00C04FD430C8", "1.2.3")
    assert_equal "42d5e23b-3a02-5135-85c6-52d1102f1f00", Digest::UUID.uuid_v5("6ba7b812-9dad-11d1-80b4-00c04fd430c8", "1.2.3")
    assert_equal "42d5e23b-3a02-5135-85c6-52d1102f1f00", Digest::UUID.uuid_v5(Digest::UUID::OID_NAMESPACE, "1.2.3")

    assert_equal "fd5b2ddf-bcfe-58b6-90d6-db50f74db527", Digest::UUID.uuid_v5("6BA7B814-9DAD-11D1-80B4-00C04FD430C8", "cn=John Doe, ou=People, o=Acme, Inc., c=US")
    assert_equal "fd5b2ddf-bcfe-58b6-90d6-db50f74db527", Digest::UUID.uuid_v5("6ba7b814-9dad-11d1-80b4-00c04fd430c8", "cn=John Doe, ou=People, o=Acme, Inc., c=US")
    assert_equal "fd5b2ddf-bcfe-58b6-90d6-db50f74db527", Digest::UUID.uuid_v5(Digest::UUID::X500_NAMESPACE, "cn=John Doe, ou=People, o=Acme, Inc., c=US")

    assert_raise ArgumentError do
      Digest::UUID.uuid_v5("A non-UUID string", "some value")
    end
  end

  def test_nil_uuid
    assert_equal "00000000-0000-0000-0000-000000000000", Digest::UUID.nil_uuid
  end

  def test_invalid_hash_class
    assert_raise ArgumentError do
      Digest::UUID.uuid_from_hash(OpenSSL::Digest::SHA256, Digest::UUID::OID_NAMESPACE, "1.2.3")
    end
  end
end
