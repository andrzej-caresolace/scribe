defmodule SocialScribe.SalesforceSuggestionsFullTest do
  @moduledoc "Extended tests for SalesforceSuggestions."
  use SocialScribe.DataCase, async: true

  import Mox

  alias SocialScribe.SalesforceSuggestions

  setup :verify_on_exit!

  @sample_contact %{
    id: "003TEST",
    firstname: "Grace",
    lastname: "Hopper",
    email: "grace@navy.mil",
    phone: "555-0000",
    jobtitle: "Admiral",
    department: "Engineering"
  }

  describe "merge_with_contact/2 - edge cases" do
    test "all suggestions match contact - returns empty" do
      suggestions = [
        %{
          field: "phone",
          new_value: "555-0000",
          current_value: nil,
          apply: false,
          has_change: true
        }
      ]

      assert SalesforceSuggestions.merge_with_contact(suggestions, @sample_contact) == []
    end

    test "nil field in contact returns nil as current_value" do
      contact = %{id: "003", firstname: "Test", lastname: "User"}

      suggestions = [
        %{
          field: "department",
          new_value: "Sales",
          current_value: nil,
          apply: false,
          has_change: true
        }
      ]

      result = SalesforceSuggestions.merge_with_contact(suggestions, contact)
      assert length(result) == 1
      assert hd(result).current_value == nil
      assert hd(result).new_value == "Sales"
      assert hd(result).apply == true
    end

    test "empty suggestions list returns empty" do
      assert SalesforceSuggestions.merge_with_contact([], @sample_contact) == []
    end

    test "preserves all suggestion fields" do
      suggestions = [
        %{
          field: "email",
          new_value: "new@example.com",
          current_value: nil,
          apply: false,
          has_change: true,
          context: "Email shared",
          timestamp: "01:30"
        }
      ]

      result = SalesforceSuggestions.merge_with_contact(suggestions, @sample_contact)
      assert length(result) == 1

      s = hd(result)
      assert s.field == "email"
      assert s.current_value == "grace@navy.mil"
      assert s.new_value == "new@example.com"
      assert s.has_change == true
      assert s.apply == true
    end
  end

  describe "generate_suggestions_from_meeting/1 - extended" do
    test "wraps multiple AI suggestions" do
      ai_result = [
        %{field: "phone", value: "555-1111", context: "Phone shared", timestamp: "00:10"},
        %{field: "email", value: "test@test.com", context: "Email given", timestamp: "00:20"},
        %{
          field: "jobtitle",
          value: "Director",
          context: "Promotion mentioned",
          timestamp: "01:00"
        }
      ]

      SocialScribe.AIContentGeneratorMock
      |> expect(:generate_salesforce_suggestions, fn _m -> {:ok, ai_result} end)

      assert {:ok, suggestions} =
               SalesforceSuggestions.generate_suggestions_from_meeting(%{id: 1})

      assert length(suggestions) == 3
      fields = Enum.map(suggestions, & &1.field)
      assert "phone" in fields
      assert "email" in fields
      assert "jobtitle" in fields
    end
  end
end
