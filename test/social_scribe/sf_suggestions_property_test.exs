defmodule SocialScribe.SfSuggestionsPropertyTest do
  @moduledoc "Property tests for SalesforceSuggestions merge logic."
  use SocialScribe.DataCase, async: true
  use ExUnitProperties

  alias SocialScribe.SalesforceSuggestions

  @known_fields ~w(firstname lastname email phone mobilephone jobtitle department address city state zip country description)

  property "merge_with_contact keeps only suggestions where new_value differs from current" do
    check all(
            field <- StreamData.member_of(@known_fields),
            new_val <- StreamData.string(:alphanumeric, min_length: 1, max_length: 30),
            has_current <- StreamData.boolean()
          ) do
      current_val = if has_current, do: new_val <> "_old", else: nil
      contact = %{String.to_atom(field) => current_val}

      raw = [
        %{field: field, new_value: new_val, current_value: nil, apply: false, has_change: true}
      ]

      merged = SalesforceSuggestions.merge_with_contact(raw, contact)

      if current_val == new_val do
        assert merged == []
      else
        assert length(merged) == 1
        assert hd(merged).apply == true
        assert hd(merged).current_value == current_val
      end
    end
  end

  property "merge_with_contact always sets apply to true" do
    check all(
            field <- StreamData.member_of(@known_fields),
            val <- StreamData.string(:alphanumeric, min_length: 1)
          ) do
      raw = [%{field: field, new_value: val, current_value: nil, apply: false, has_change: true}]
      contact = %{}

      merged = SalesforceSuggestions.merge_with_contact(raw, contact)
      assert Enum.all?(merged, fn s -> s.apply == true end)
    end
  end
end
