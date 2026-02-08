defmodule SocialScribe.SalesforceSuggestionsExtendedTest do
  @moduledoc "Extended tests for SalesforceSuggestions - generate_suggestions/3."
  use SocialScribe.DataCase, async: true

  import Mox
  import SocialScribe.AccountsFixtures

  alias SocialScribe.SalesforceSuggestions

  setup :verify_on_exit!

  describe "generate_suggestions/3" do
    test "returns merged suggestions when contact and AI succeed" do
      cred = make_salesforce_cred()

      contact = %{
        id: "003TEST",
        firstname: "Grace",
        lastname: "Hopper",
        email: "grace@navy.mil",
        phone: nil,
        jobtitle: "Admiral",
        department: "Engineering"
      }

      ai_result = [
        %{field: "phone", value: "555-1234", context: "Phone shared", timestamp: "01:00"},
        %{
          field: "jobtitle",
          value: "Admiral",
          context: "Title same",
          timestamp: "02:00"
        }
      ]

      SocialScribe.MockSalesforceClient
      |> expect(:get_contact, fn _c, "003TEST" -> {:ok, contact} end)

      SocialScribe.AIContentGeneratorMock
      |> expect(:generate_salesforce_suggestions, fn _m -> {:ok, ai_result} end)

      assert {:ok, %{contact: ^contact, suggestions: suggestions}} =
               SalesforceSuggestions.generate_suggestions(cred, "003TEST", %{id: 1})

      # jobtitle matches existing, so only phone should remain
      assert length(suggestions) == 1
      assert hd(suggestions).field == "phone"
      assert hd(suggestions).new_value == "555-1234"
      assert hd(suggestions).has_change == true
      assert hd(suggestions).apply == true
    end

    test "returns error when contact fetch fails" do
      cred = make_salesforce_cred()

      SocialScribe.MockSalesforceClient
      |> expect(:get_contact, fn _c, "bad_id" -> {:error, :not_found} end)

      assert {:error, :not_found} =
               SalesforceSuggestions.generate_suggestions(cred, "bad_id", %{id: 1})
    end

    test "returns error when AI generation fails" do
      cred = make_salesforce_cred()

      SocialScribe.MockSalesforceClient
      |> expect(:get_contact, fn _c, "003x" -> {:ok, %{id: "003x", phone: nil}} end)

      SocialScribe.AIContentGeneratorMock
      |> expect(:generate_salesforce_suggestions, fn _m -> {:error, :quota_exceeded} end)

      assert {:error, :quota_exceeded} =
               SalesforceSuggestions.generate_suggestions(cred, "003x", %{id: 1})
    end

    test "filters out suggestions with same current and new values" do
      cred = make_salesforce_cred()

      contact = %{
        id: "003A",
        firstname: "Alice",
        lastname: "Smith",
        email: "alice@test.com",
        phone: "555-0000"
      }

      ai_result = [
        %{field: "phone", value: "555-0000", context: "Same phone", timestamp: "00:10"},
        %{field: "email", value: "alice@test.com", context: "Same email", timestamp: "00:20"},
        %{field: "firstname", value: "Alice", context: "Same name", timestamp: "00:30"}
      ]

      SocialScribe.MockSalesforceClient
      |> expect(:get_contact, fn _c, "003A" -> {:ok, contact} end)

      SocialScribe.AIContentGeneratorMock
      |> expect(:generate_salesforce_suggestions, fn _m -> {:ok, ai_result} end)

      assert {:ok, %{suggestions: []}} =
               SalesforceSuggestions.generate_suggestions(cred, "003A", %{id: 1})
    end
  end

  describe "generate_suggestions_from_meeting/1 - extended" do
    test "returns error when AI fails" do
      SocialScribe.AIContentGeneratorMock
      |> expect(:generate_salesforce_suggestions, fn _m -> {:error, :api_down} end)

      assert {:error, :api_down} =
               SalesforceSuggestions.generate_suggestions_from_meeting(%{id: 1})
    end

    test "returns empty list when AI finds nothing" do
      SocialScribe.AIContentGeneratorMock
      |> expect(:generate_salesforce_suggestions, fn _m -> {:ok, []} end)

      assert {:ok, []} = SalesforceSuggestions.generate_suggestions_from_meeting(%{id: 1})
    end

    test "maps AI suggestions with has_change true and nil current_value" do
      ai_result = [
        %{field: "department", value: "Sales", context: "Dept mentioned", timestamp: "01:30"}
      ]

      SocialScribe.AIContentGeneratorMock
      |> expect(:generate_salesforce_suggestions, fn _m -> {:ok, ai_result} end)

      assert {:ok, suggestions} =
               SalesforceSuggestions.generate_suggestions_from_meeting(%{id: 1})

      assert length(suggestions) == 1
      s = hd(suggestions)
      assert s.field == "department"
      assert s.current_value == nil
      assert s.new_value == "Sales"
      assert s.has_change == true
      assert s.apply == true
      assert s.label == "Department"
    end
  end

  describe "merge_with_contact/2 - additional edge cases" do
    test "handles non-existent field atom" do
      contact = %{id: "003", firstname: "Test"}

      suggestions = [
        %{
          field: "nonexistent_weird_field_xyz_999",
          new_value: "something",
          current_value: nil,
          apply: false,
          has_change: true
        }
      ]

      result = SalesforceSuggestions.merge_with_contact(suggestions, contact)
      assert length(result) == 1
      assert hd(result).current_value == nil
    end

    test "handles nil contact" do
      suggestions = [
        %{
          field: "email",
          new_value: "test@test.com",
          current_value: nil,
          apply: false,
          has_change: true
        }
      ]

      result = SalesforceSuggestions.merge_with_contact(suggestions, nil)
      assert length(result) == 1
      assert hd(result).current_value == nil
    end
  end
end
