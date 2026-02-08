defmodule SocialScribe.SfClientTest do
  @moduledoc "Tests for SalesforceApi through the SalesforceClientSpec behaviour."
  use SocialScribe.DataCase, async: true

  import Mox
  import SocialScribe.AccountsFixtures

  alias SocialScribe.SalesforceClientSpec

  setup :verify_on_exit!

  defp make_cred do
    make_salesforce_cred()
  end

  describe "search_contacts/2 via spec" do
    test "delegates to the configured adapter and returns contacts" do
      cred = make_cred()
      expected = [%{id: "003", display_name: "Ada Lovelace"}]

      SocialScribe.MockSalesforceClient
      |> expect(:search_contacts, fn ^cred, "Ada" -> {:ok, expected} end)

      assert {:ok, ^expected} = SalesforceClientSpec.search_contacts(cred, "Ada")
    end

    test "propagates errors from the adapter" do
      cred = make_cred()

      SocialScribe.MockSalesforceClient
      |> expect(:search_contacts, fn _c, _q -> {:error, :timeout} end)

      assert {:error, :timeout} = SalesforceClientSpec.search_contacts(cred, "x")
    end
  end

  describe "get_contact/2 via spec" do
    test "returns a single contact map" do
      cred = make_cred()
      expected = %{id: "003x", firstname: "Grace", lastname: "Hopper"}

      SocialScribe.MockSalesforceClient
      |> expect(:get_contact, fn ^cred, "003x" -> {:ok, expected} end)

      assert {:ok, ^expected} = SalesforceClientSpec.get_contact(cred, "003x")
    end
  end

  describe "update_contact/3 via spec" do
    test "sends a patch and returns updated contact" do
      cred = make_cred()
      patch = %{"Title" => "CTO"}
      updated = %{id: "003x", jobtitle: "CTO"}

      SocialScribe.MockSalesforceClient
      |> expect(:update_contact, fn ^cred, "003x", ^patch -> {:ok, updated} end)

      assert {:ok, ^updated} = SalesforceClientSpec.update_contact(cred, "003x", patch)
    end
  end

  describe "apply_updates/3 via spec" do
    test "returns :no_updates when nothing to apply" do
      cred = make_cred()

      SocialScribe.MockSalesforceClient
      |> expect(:apply_updates, fn _c, _id, [] -> {:ok, :no_updates} end)

      assert {:ok, :no_updates} = SalesforceClientSpec.apply_updates(cred, "003x", [])
    end
  end
end
