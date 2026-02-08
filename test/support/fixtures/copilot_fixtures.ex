defmodule SocialScribe.CopilotFixtures do
  @moduledoc "Factory helpers for copilot session / turn test data."

  import SocialScribe.AccountsFixtures

  alias SocialScribe.CrmCopilot

  def build_session(overrides \\ %{}) do
    owner = overrides[:user_id] || user_fixture().id

    {:ok, sess} =
      %{user_id: owner, label: Map.get(overrides, :label, "Test session")}
      |> Map.merge(overrides)
      |> CrmCopilot.start_session()

    sess
  end

  def build_turn(overrides \\ %{}) do
    sid = overrides[:session_id] || build_session().id

    {:ok, turn} =
      %{session_id: sid, sender: "human", body: "Hello copilot"}
      |> Map.merge(overrides)
      |> CrmCopilot.add_turn()

    turn
  end
end
