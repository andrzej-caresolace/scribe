defmodule SocialScribe.SfClientPropertyTest do
  @moduledoc "Property tests ensuring SalesforceClientSpec delegates correctly for any input."
  use SocialScribe.DataCase, async: true
  use ExUnitProperties

  import Mox
  import SocialScribe.AccountsFixtures

  alias SocialScribe.SalesforceClientSpec

  setup :verify_on_exit!

  property "search_contacts forwards arbitrary query strings" do
    cred = make_salesforce_cred()

    check all(query <- StreamData.string(:alphanumeric, min_length: 1, max_length: 50)) do
      SocialScribe.MockSalesforceClient
      |> expect(:search_contacts, fn _c, q -> {:ok, [%{query: q}]} end)

      assert {:ok, [%{query: ^query}]} = SalesforceClientSpec.search_contacts(cred, query)
    end
  end

  property "get_contact forwards arbitrary contact IDs" do
    cred = make_salesforce_cred()

    check all(cid <- StreamData.string(:alphanumeric, min_length: 5, max_length: 18)) do
      SocialScribe.MockSalesforceClient
      |> expect(:get_contact, fn _c, id -> {:ok, %{id: id}} end)

      assert {:ok, %{id: ^cid}} = SalesforceClientSpec.get_contact(cred, cid)
    end
  end
end
