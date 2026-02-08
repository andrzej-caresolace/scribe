defmodule SocialScribe.CopilotPropertyTest do
  @moduledoc "Property-based tests for the CrmCopilot context."
  use SocialScribe.DataCase, async: true
  use ExUnitProperties

  import SocialScribe.AccountsFixtures

  alias SocialScribe.CrmCopilot

  property "any non-empty string is accepted as a turn body" do
    user = user_fixture()
    {:ok, sess} = CrmCopilot.start_session(%{user_id: user.id})

    check all(
            body <- StreamData.string(:printable, min_length: 1),
            sender <- StreamData.member_of(["human", "copilot"])
          ) do
      assert {:ok, turn} =
               CrmCopilot.add_turn(%{session_id: sess.id, sender: sender, body: body})

      assert turn.body == body
      assert turn.sender == sender
    end
  end

  property "session label round-trips through the database" do
    user = user_fixture()

    check all(label <- StreamData.string(:printable, min_length: 1, max_length: 200)) do
      assert {:ok, sess} = CrmCopilot.start_session(%{user_id: user.id, label: label})
      loaded = CrmCopilot.fetch_session!(sess.id)
      assert loaded.label == label
    end
  end

  property "turns_for_session always returns results sorted ascending" do
    user = user_fixture()
    {:ok, sess} = CrmCopilot.start_session(%{user_id: user.id})

    check all(
            bodies <-
              StreamData.list_of(StreamData.string(:printable, min_length: 1),
                min_length: 1,
                max_length: 5
              )
          ) do
      for b <- bodies do
        CrmCopilot.add_turn(%{session_id: sess.id, sender: "human", body: b})
      end

      turns = CrmCopilot.turns_for_session(sess.id)
      timestamps = Enum.map(turns, & &1.inserted_at)
      assert timestamps == Enum.sort(timestamps, DateTime)
    end
  end
end
