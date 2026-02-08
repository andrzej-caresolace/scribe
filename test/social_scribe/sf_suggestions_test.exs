defmodule SocialScribe.SfSuggestionsTest do
  @moduledoc "Tests for SalesforceSuggestions generation and merging."
  use SocialScribe.DataCase, async: true

  import Mox

  alias SocialScribe.SalesforceSuggestions

  setup :verify_on_exit!

  @sample_contact %{
    id: "003TEST",
    firstname: "Ada",
    lastname: "Lovelace",
    email: "ada@example.com",
    phone: nil,
    jobtitle: "Mathematician"
  }

  describe "generate_suggestions_from_meeting/1" do
    test "wraps AI suggestions into structured format" do
      ai_result = [
        %{
          field: "phone",
          value: "555-0042",
          context: "Ada shared her number",
          timestamp: "02:30"
        },
        %{
          field: "jobtitle",
          value: "Lead Engineer",
          context: "New title mentioned",
          timestamp: "05:10"
        }
      ]

      SocialScribe.AIContentGeneratorMock
      |> expect(:generate_salesforce_suggestions, fn _meeting -> {:ok, ai_result} end)

      assert {:ok, suggestions} =
               SalesforceSuggestions.generate_suggestions_from_meeting(%{id: 1})

      assert length(suggestions) == 2
      assert Enum.all?(suggestions, fn s -> s.apply == true end)
      assert Enum.all?(suggestions, fn s -> s.has_change == true end)
    end

    test "returns empty list when AI finds nothing" do
      SocialScribe.AIContentGeneratorMock
      |> expect(:generate_salesforce_suggestions, fn _m -> {:ok, []} end)

      assert {:ok, []} = SalesforceSuggestions.generate_suggestions_from_meeting(%{id: 1})
    end

    test "surfaces AI errors" do
      SocialScribe.AIContentGeneratorMock
      |> expect(:generate_salesforce_suggestions, fn _m -> {:error, :quota_exceeded} end)

      assert {:error, :quota_exceeded} =
               SalesforceSuggestions.generate_suggestions_from_meeting(%{id: 1})
    end
  end

  describe "merge_with_contact/2" do
    test "populates current_value and filters unchanged fields" do
      raw = [
        %{
          field: "jobtitle",
          new_value: "Mathematician",
          current_value: nil,
          apply: false,
          has_change: true
        },
        %{
          field: "phone",
          new_value: "555-0042",
          current_value: nil,
          apply: false,
          has_change: true
        }
      ]

      merged = SalesforceSuggestions.merge_with_contact(raw, @sample_contact)

      # jobtitle matches current value → filtered out
      assert length(merged) == 1
      phone_s = hd(merged)
      assert phone_s.field == "phone"
      assert phone_s.current_value == nil
      assert phone_s.new_value == "555-0042"
      assert phone_s.apply == true
    end
  end
end
