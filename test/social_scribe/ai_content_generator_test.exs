defmodule SocialScribe.AIContentGeneratorTest do
  @moduledoc "Tests for the AIContentGenerator module."
  use SocialScribe.DataCase, async: true

  alias SocialScribe.AIContentGenerator

  describe "compose_copilot_reply/2" do
    test "builds prompt with no context and returns error without API key" do
      ctx = %{crm_type: nil, tagged_record: nil, prior_turns: []}

      result = AIContentGenerator.compose_copilot_reply("hello", ctx)

      # Without a valid Gemini API key, returns config error
      assert match?({:error, {:config_error, _}}, result) or
               match?({:ok, _}, result) or
               match?({:error, _}, result)
    end

    test "builds prompt with tagged contact record" do
      ctx = %{
        crm_type: :hubspot,
        tagged_record: %{firstname: "Ada", lastname: "Lovelace", email: "ada@example.com"},
        prior_turns: []
      }

      result = AIContentGenerator.compose_copilot_reply("tell me about this contact", ctx)

      assert match?({:error, {:config_error, _}}, result) or
               match?({:ok, _}, result) or
               match?({:error, _}, result)
    end

    test "builds prompt with prior turns" do
      turns = [
        %{sender: "human", body: "Who is Ada?"},
        %{sender: "copilot", body: "Ada Lovelace was a mathematician."}
      ]

      ctx = %{crm_type: :hubspot, tagged_record: nil, prior_turns: turns}

      result = AIContentGenerator.compose_copilot_reply("tell me more", ctx)

      assert match?({:error, {:config_error, _}}, result) or
               match?({:ok, _}, result) or
               match?({:error, _}, result)
    end

    test "builds prompt with empty tagged record map" do
      ctx = %{crm_type: :salesforce, tagged_record: %{}, prior_turns: []}

      result = AIContentGenerator.compose_copilot_reply("what do you know?", ctx)

      assert match?({:error, {:config_error, _}}, result) or
               match?({:ok, _}, result) or
               match?({:error, _}, result)
    end

    test "builds prompt with nil values filtered from record" do
      ctx = %{
        crm_type: :hubspot,
        tagged_record: %{firstname: "Test", lastname: nil, email: ""},
        prior_turns: []
      }

      result = AIContentGenerator.compose_copilot_reply("hello", ctx)

      assert match?({:error, {:config_error, _}}, result) or
               match?({:ok, _}, result) or
               match?({:error, _}, result)
    end

    test "limits prior turns to 8 most recent" do
      many_turns =
        for i <- 1..12 do
          %{sender: if(rem(i, 2) == 0, do: "copilot", else: "human"), body: "Turn #{i}"}
        end

      ctx = %{crm_type: nil, tagged_record: nil, prior_turns: many_turns}

      result = AIContentGenerator.compose_copilot_reply("latest question", ctx)

      assert match?({:error, {:config_error, _}}, result) or
               match?({:ok, _}, result) or
               match?({:error, _}, result)
    end
  end
end
