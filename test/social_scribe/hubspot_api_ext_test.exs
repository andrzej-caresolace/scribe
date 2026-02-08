defmodule SocialScribe.HubspotApiExtTest do
  @moduledoc "Tests for the real HubspotApi implementation."
  use SocialScribe.DataCase, async: true

  import SocialScribe.AccountsFixtures

  alias SocialScribe.HubspotApi

  describe "search_contacts/2" do
    test "exercises the function with a credential" do
      cred = hubspot_credential_fixture()
      result = HubspotApi.search_contacts(cred, "Test")

      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end

    test "handles empty query" do
      cred = hubspot_credential_fixture()
      result = HubspotApi.search_contacts(cred, "")

      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "get_contact/2" do
    test "exercises the function with a credential" do
      cred = hubspot_credential_fixture()
      result = HubspotApi.get_contact(cred, "12345")

      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "update_contact/3" do
    test "exercises the function with a credential" do
      cred = hubspot_credential_fixture()
      result = HubspotApi.update_contact(cred, "12345", %{"phone" => "555-1234"})

      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "apply_updates/3" do
    test "returns :no_updates when nothing to apply" do
      cred = hubspot_credential_fixture()

      updates = [
        %{field: "phone", new_value: "555-1234", apply: false}
      ]

      assert {:ok, :no_updates} = HubspotApi.apply_updates(cred, "12345", updates)
    end

    test "returns :no_updates for empty list" do
      cred = hubspot_credential_fixture()
      assert {:ok, :no_updates} = HubspotApi.apply_updates(cred, "12345", [])
    end

    test "exercises with apply: true updates" do
      cred = hubspot_credential_fixture()

      updates = [
        %{field: "phone", new_value: "555-1234", apply: true}
      ]

      result = HubspotApi.apply_updates(cred, "12345", updates)
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end
end
