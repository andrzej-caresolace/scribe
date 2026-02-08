defmodule SocialScribe.CrmCopilotTest do
  @moduledoc "Tests for the CrmCopilot context — sessions & turns CRUD."
  use SocialScribe.DataCase, async: true

  import SocialScribe.AccountsFixtures
  import SocialScribe.CopilotFixtures

  alias SocialScribe.CrmCopilot

  describe "start_session/1" do
    test "creates a session owned by the given user" do
      user = user_fixture()
      assert {:ok, sess} = CrmCopilot.start_session(%{user_id: user.id})
      assert sess.user_id == user.id
      assert is_nil(sess.label)
    end

    test "rejects missing user_id" do
      assert {:error, changeset} = CrmCopilot.start_session(%{})
      assert %{user_id: [_ | _]} = errors_on(changeset)
    end

    test "persists an optional label" do
      user = user_fixture()
      assert {:ok, sess} = CrmCopilot.start_session(%{user_id: user.id, label: "My topic"})
      assert sess.label == "My topic"
    end
  end

  describe "sessions_for_user/1" do
    test "returns all sessions for the user" do
      user = user_fixture()
      s1 = build_session(%{user_id: user.id, label: "First"})
      s2 = build_session(%{user_id: user.id, label: "Second"})

      result = CrmCopilot.sessions_for_user(user.id)
      ids = Enum.map(result, & &1.id)

      assert length(ids) == 2
      assert s1.id in ids
      assert s2.id in ids
    end

    test "excludes other users' sessions" do
      u1 = user_fixture()
      u2 = user_fixture()
      _s1 = build_session(%{user_id: u1.id})

      assert CrmCopilot.sessions_for_user(u2.id) == []
    end
  end

  describe "load_session!/1" do
    test "returns session with ordered turns preloaded" do
      sess = build_session()
      {:ok, _t1} = CrmCopilot.add_turn(%{session_id: sess.id, sender: "human", body: "First"})
      {:ok, _t2} = CrmCopilot.add_turn(%{session_id: sess.id, sender: "copilot", body: "Second"})

      loaded = CrmCopilot.load_session!(sess.id)
      assert length(loaded.turns) == 2
      assert hd(loaded.turns).body == "First"
    end
  end

  describe "destroy_session/1" do
    test "removes the session and cascades to turns" do
      sess = build_session()
      _turn = build_turn(%{session_id: sess.id})

      assert {:ok, _} = CrmCopilot.destroy_session(sess)
      assert CrmCopilot.turns_for_session(sess.id) == []
    end
  end

  describe "add_turn/1" do
    test "persists a human turn" do
      sess = build_session()

      assert {:ok, turn} =
               CrmCopilot.add_turn(%{session_id: sess.id, sender: "human", body: "Hey"})

      assert turn.sender == "human"
      assert turn.body == "Hey"
      assert turn.extras == %{}
    end

    test "persists a copilot turn with extras" do
      sess = build_session()
      extras = %{"sources" => [%{"crm" => "salesforce", "name" => "Jane"}]}

      assert {:ok, turn} =
               CrmCopilot.add_turn(%{
                 session_id: sess.id,
                 sender: "copilot",
                 body: "Here you go",
                 extras: extras
               })

      assert turn.extras["sources"] != nil
    end

    test "rejects unknown sender value" do
      sess = build_session()

      assert {:error, cs} =
               CrmCopilot.add_turn(%{session_id: sess.id, sender: "alien", body: "beep"})

      assert %{sender: [_ | _]} = errors_on(cs)
    end

    test "rejects blank body" do
      sess = build_session()

      assert {:error, cs} =
               CrmCopilot.add_turn(%{session_id: sess.id, sender: "human", body: nil})

      assert %{body: [_ | _]} = errors_on(cs)
    end
  end

  describe "turns_for_session/1" do
    test "returns turns sorted by creation time" do
      sess = build_session()
      {:ok, t1} = CrmCopilot.add_turn(%{session_id: sess.id, sender: "human", body: "A"})
      {:ok, t2} = CrmCopilot.add_turn(%{session_id: sess.id, sender: "copilot", body: "B"})

      turns = CrmCopilot.turns_for_session(sess.id)
      assert Enum.map(turns, & &1.id) == [t1.id, t2.id]
    end
  end
end
