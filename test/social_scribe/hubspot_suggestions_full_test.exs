defmodule SocialScribe.HubspotSuggestionsFullTest do
  @moduledoc "Extended tests for HubspotSuggestions - generate_suggestions + generate_suggestions_from_meeting."
  use SocialScribe.DataCase

  import Mox
  import SocialScribe.AccountsFixtures

  alias SocialScribe.HubspotSuggestions

  setup :verify_on_exit!

  describe "generate_suggestions/3" do
    test "returns merged suggestions when both contact and AI succeed" do
      cred = hubspot_credential_fixture()

      contact = %{
        id: "123",
        firstname: "Ada",
        lastname: "Lovelace",
        email: "ada@example.com",
        phone: nil,
        company: "Babbage Inc"
      }

      ai_result = [
        %{field: "phone", value: "555-1234", context: "Phone mentioned", timestamp: "01:00"},
        %{
          field: "company",
          value: "Babbage Inc",
          context: "Company same as existing",
          timestamp: "02:00"
        }
      ]

      SocialScribe.HubspotApiMock
      |> expect(:get_contact, fn _c, "123" -> {:ok, contact} end)

      SocialScribe.AIContentGeneratorMock
      |> expect(:generate_hubspot_suggestions, fn _m -> {:ok, ai_result} end)

      meeting = %{id: 1}

      assert {:ok, %{contact: ^contact, suggestions: suggestions}} =
               HubspotSuggestions.generate_suggestions(cred, "123", meeting)

      # company matches, so only phone should remain
      assert length(suggestions) == 1
      assert hd(suggestions).field == "phone"
      assert hd(suggestions).new_value == "555-1234"
    end

    test "returns error when contact fetch fails" do
      cred = hubspot_credential_fixture()

      SocialScribe.HubspotApiMock
      |> expect(:get_contact, fn _c, "bad" -> {:error, :not_found} end)

      assert {:error, :not_found} =
               HubspotSuggestions.generate_suggestions(cred, "bad", %{id: 1})
    end

    test "returns error when AI generation fails" do
      cred = hubspot_credential_fixture()

      SocialScribe.HubspotApiMock
      |> expect(:get_contact, fn _c, "123" ->
        {:ok, %{id: "123", phone: nil, company: nil}}
      end)

      SocialScribe.AIContentGeneratorMock
      |> expect(:generate_hubspot_suggestions, fn _m -> {:error, :quota_exceeded} end)

      assert {:error, :quota_exceeded} =
               HubspotSuggestions.generate_suggestions(cred, "123", %{id: 1})
    end
  end

  describe "generate_suggestions_from_meeting/1" do
    test "formats AI suggestions with apply and has_change flags" do
      ai_result = [
        %{field: "phone", value: "555-9999", context: "Shared number", timestamp: "00:30"},
        %{
          field: "jobtitle",
          value: "CTO",
          context: "Title mentioned",
          timestamp: "03:00"
        }
      ]

      SocialScribe.AIContentGeneratorMock
      |> expect(:generate_hubspot_suggestions, fn _m -> {:ok, ai_result} end)

      assert {:ok, suggestions} = HubspotSuggestions.generate_suggestions_from_meeting(%{id: 1})

      assert length(suggestions) == 2
      assert Enum.all?(suggestions, fn s -> s.apply == true end)
      assert Enum.all?(suggestions, fn s -> s.has_change == true end)
      assert Enum.all?(suggestions, fn s -> s.current_value == nil end)
    end

    test "returns empty list when AI finds nothing" do
      SocialScribe.AIContentGeneratorMock
      |> expect(:generate_hubspot_suggestions, fn _m -> {:ok, []} end)

      assert {:ok, []} = HubspotSuggestions.generate_suggestions_from_meeting(%{id: 1})
    end

    test "propagates AI error" do
      SocialScribe.AIContentGeneratorMock
      |> expect(:generate_hubspot_suggestions, fn _m -> {:error, :api_down} end)

      assert {:error, :api_down} = HubspotSuggestions.generate_suggestions_from_meeting(%{id: 1})
    end
  end
end
