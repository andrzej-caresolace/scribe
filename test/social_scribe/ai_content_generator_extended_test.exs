defmodule SocialScribe.AIContentGeneratorExtendedTest do
  @moduledoc "Extended tests for AIContentGenerator covering more functions and code paths."
  use SocialScribe.DataCase, async: false

  import SocialScribe.AccountsFixtures
  import SocialScribe.MeetingsFixtures

  alias SocialScribe.AIContentGenerator
  alias SocialScribe.Meetings

  # Temporarily clear the Gemini API key so the real implementation returns {:error, {:config_error, _}}
  # instead of hitting the actual API.
  setup do
    original = Application.get_env(:social_scribe, :gemini_api_key)
    Application.put_env(:social_scribe, :gemini_api_key, nil)
    on_exit(fn -> Application.put_env(:social_scribe, :gemini_api_key, original) end)
    :ok
  end

  defp build_meeting_with_transcript do
    user = user_fixture()
    meeting = meeting_fixture(%{})
    calendar_event = SocialScribe.Calendar.get_calendar_event!(meeting.calendar_event_id)
    {:ok, _} = SocialScribe.Calendar.update_calendar_event(calendar_event, %{user_id: user.id})

    meeting_participant_fixture(%{meeting_id: meeting.id, name: "Jane Doe", is_host: true})

    meeting_transcript_fixture(%{
      meeting_id: meeting.id,
      content: %{
        "data" => [
          %{
            "speaker" => "Jane Doe",
            "words" => [
              %{"text" => "My", "start_timestamp" => 0.5},
              %{"text" => "phone", "start_timestamp" => 1.0},
              %{"text" => "is", "start_timestamp" => 1.5},
              %{"text" => "555-1234", "start_timestamp" => 2.0}
            ]
          }
        ]
      }
    })

    Meetings.get_meeting_with_details(meeting.id)
  end

  describe "generate_follow_up_email/1" do
    test "returns config error when API key is missing" do
      meeting = build_meeting_with_transcript()
      result = AIContentGenerator.generate_follow_up_email(meeting)
      assert match?({:error, {:config_error, _}}, result)
    end

    test "returns error when meeting has no participants" do
      meeting = meeting_fixture(%{})
      meeting = Meetings.get_meeting_with_details(meeting.id)
      result = AIContentGenerator.generate_follow_up_email(meeting)
      assert {:error, :no_participants} = result
    end
  end

  describe "generate_automation/2" do
    test "returns config error with valid meeting and automation" do
      meeting = build_meeting_with_transcript()

      automation = %SocialScribe.Automations.Automation{
        id: 1,
        name: "Test Automation",
        description: "Summarize the meeting",
        example: "Here is a summary...",
        platform: :linkedin
      }

      result = AIContentGenerator.generate_automation(automation, meeting)
      assert match?({:error, {:config_error, _}}, result)
    end

    test "returns error when meeting has no transcript" do
      meeting = meeting_fixture(%{})
      meeting_participant_fixture(%{meeting_id: meeting.id, name: "Test", is_host: true})
      meeting = Meetings.get_meeting_with_details(meeting.id)

      automation = %SocialScribe.Automations.Automation{
        id: 1,
        name: "Test Automation",
        description: "Summarize the meeting",
        example: "Here is a summary...",
        platform: :linkedin
      }

      result = AIContentGenerator.generate_automation(automation, meeting)
      assert {:error, :no_transcript} = result
    end
  end

  describe "generate_hubspot_suggestions/1" do
    test "returns config error with valid meeting" do
      meeting = build_meeting_with_transcript()
      result = AIContentGenerator.generate_hubspot_suggestions(meeting)
      assert match?({:error, {:config_error, _}}, result)
    end

    test "returns error when meeting has no participants" do
      meeting = meeting_fixture(%{})
      meeting = Meetings.get_meeting_with_details(meeting.id)
      result = AIContentGenerator.generate_hubspot_suggestions(meeting)
      assert {:error, :no_participants} = result
    end
  end

  describe "generate_salesforce_suggestions/1" do
    test "returns config error with valid meeting" do
      meeting = build_meeting_with_transcript()
      result = AIContentGenerator.generate_salesforce_suggestions(meeting)
      assert match?({:error, {:config_error, _}}, result)
    end

    test "returns error when meeting has no transcript" do
      meeting = meeting_fixture(%{})
      meeting_participant_fixture(%{meeting_id: meeting.id, name: "Bob", is_host: true})
      meeting = Meetings.get_meeting_with_details(meeting.id)
      result = AIContentGenerator.generate_salesforce_suggestions(meeting)
      assert {:error, :no_transcript} = result
    end
  end

  describe "compose_copilot_reply/2 - additional paths" do
    test "handles nil crm_type in context" do
      ctx = %{tagged_record: nil, prior_turns: []}
      result = AIContentGenerator.compose_copilot_reply("hello", ctx)
      assert match?({:error, {:config_error, _}}, result)
    end

    test "handles record with all nil values" do
      ctx = %{
        crm_type: :salesforce,
        tagged_record: %{firstname: nil, lastname: nil, email: nil},
        prior_turns: []
      }

      result = AIContentGenerator.compose_copilot_reply("who is this?", ctx)
      assert match?({:error, {:config_error, _}}, result)
    end

    test "handles more than 8 prior turns (truncation)" do
      turns =
        for i <- 1..15 do
          %{sender: if(rem(i, 2) == 0, do: "copilot", else: "human"), body: "Message #{i}"}
        end

      ctx = %{crm_type: :hubspot, tagged_record: nil, prior_turns: turns}
      result = AIContentGenerator.compose_copilot_reply("latest?", ctx)
      assert match?({:error, {:config_error, _}}, result)
    end

    test "handles context without prior_turns key" do
      ctx = %{crm_type: :hubspot, tagged_record: nil}
      result = AIContentGenerator.compose_copilot_reply("hello", ctx)
      assert match?({:error, {:config_error, _}}, result)
    end
  end
end
