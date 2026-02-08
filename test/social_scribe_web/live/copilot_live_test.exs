defmodule SocialScribeWeb.CopilotLiveTest do
  use SocialScribeWeb.ConnCase

  import Phoenix.LiveViewTest
  import SocialScribe.AccountsFixtures
  import Mox

  setup :verify_on_exit!

  describe "CopilotLive.Assistant - unauthenticated" do
    test "redirects to login when not logged in", %{conn: conn} do
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/dashboard/copilot")
      assert path == ~p"/users/log_in"
    end
  end

  describe "CopilotLive.Assistant - authenticated, no CRM" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "renders copilot page", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/dashboard/copilot")

      assert html =~ "CRM Copilot"
      assert has_element?(view, "#composer")
      assert has_element?(view, "textarea#copilot-input")
    end

    test "shows no CRM connected hint", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/copilot")

      assert html =~ "Connect HubSpot or Salesforce in Settings first"
    end

    test "shows empty sessions list", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/copilot")

      assert html =~ "No sessions yet"
    end

    test "begin_session clears state", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/copilot")

      view
      |> element("button[phx-click='begin_session']")
      |> render_click()

      assert_patch(view, ~p"/dashboard/copilot")
    end

    test "mention_lookup with empty query shows popup", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/copilot")

      view
      |> element("#composer")
      |> render_hook("mention_lookup", %{"q" => ""})

      html = render(view)
      assert html =~ "No CRM connected"
    end

    test "dismiss_mentions hides the popup", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/copilot")

      # First show the popup
      view |> element("#composer") |> render_hook("mention_lookup", %{"q" => ""})
      assert render(view) =~ "No CRM connected"

      # Then dismiss it
      view |> element("#composer") |> render_hook("dismiss_mentions", %{})
      refute render(view) =~ "No CRM connected"
    end

    test "show_panel toggles between sessions and dialogue", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/copilot")

      view |> element("button[phx-value-which='sessions']") |> render_click()
      html = render(view)
      assert html =~ "Sessions"

      view |> element("button[phx-value-which='dialogue']") |> render_click()
      _html = render(view)
    end

    test "can submit a question and creates a session", %{conn: conn} do
      SocialScribe.AIContentGeneratorMock
      |> expect(:compose_copilot_reply, fn _question, _ctx ->
        {:ok, "I'm your CRM copilot! How can I help?"}
      end)

      {:ok, view, _html} = live(conn, ~p"/dashboard/copilot")

      view
      |> element("#composer")
      |> render_hook("submit_question", %{"question" => "Hello copilot"})

      # The human turn should appear
      html = render(view)
      assert html =~ "Hello copilot"

      # Wait for async copilot reply
      :timer.sleep(300)
      html = render(view)
      assert html =~ "CRM copilot"
    end
  end

  describe "CopilotLive.Assistant - with HubSpot connected" do
    setup %{conn: conn} do
      user = user_fixture()
      cred = hubspot_credential_fixture(%{user_id: user.id})
      %{conn: log_in_user(conn, user), user: user, cred: cred}
    end

    test "shows HubSpot icon in sources", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/copilot")

      assert html =~ "HubSpot"
    end

    test "pin_contact sets the pinned contact", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/copilot")

      view
      |> element("#composer")
      |> render_hook("pin_contact", %{
        "cid" => "123",
        "label" => "Ada Lovelace",
        "src" => "hubspot"
      })

      html = render(view)
      assert html =~ "Ada Lovelace"
    end
  end

  describe "CopilotLive.Assistant - with Salesforce connected" do
    setup %{conn: conn} do
      user = user_fixture()
      cred = make_salesforce_cred(%{user_id: user.id})
      %{conn: log_in_user(conn, user), user: user, cred: cred}
    end

    test "shows Salesforce icon in sources", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/copilot")

      assert html =~ "Salesforce"
    end
  end

  describe "CopilotLive.Assistant - with both CRMs connected" do
    setup %{conn: conn} do
      user = user_fixture()
      _hub_cred = hubspot_credential_fixture(%{user_id: user.id})
      _sf_cred = make_salesforce_cred(%{user_id: user.id})
      %{conn: log_in_user(conn, user), user: user}
    end

    test "shows both CRM icons in sources", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/copilot")

      assert html =~ "HubSpot"
      assert html =~ "Salesforce"
    end
  end

  describe "CopilotLive.Assistant - session management" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "creates session on first question", %{conn: conn, user: user} do
      SocialScribe.AIContentGeneratorMock
      |> expect(:compose_copilot_reply, fn _q, _ctx -> {:ok, "Hello!"} end)

      {:ok, view, _html} = live(conn, ~p"/dashboard/copilot")

      view
      |> element("#composer")
      |> render_hook("submit_question", %{"question" => "Hi there"})

      :timer.sleep(300)

      sessions = SocialScribe.CrmCopilot.sessions_for_user(user.id)
      assert length(sessions) >= 1
    end

    test "navigating to session loads its turns", %{conn: conn, user: user} do
      {:ok, sess} = SocialScribe.CrmCopilot.start_session(%{user_id: user.id, label: "Test"})

      {:ok, _turn} =
        SocialScribe.CrmCopilot.add_turn(%{
          session_id: sess.id,
          sender: "human",
          body: "Previously asked"
        })

      {:ok, _view, html} = live(conn, ~p"/dashboard/copilot/#{sess.id}")

      assert html =~ "Previously asked"
    end

    test "remove_session deletes session", %{conn: conn, user: user} do
      {:ok, sess} =
        SocialScribe.CrmCopilot.start_session(%{user_id: user.id, label: "Delete me"})

      {:ok, view, _html} = live(conn, ~p"/dashboard/copilot")

      view
      |> element("button[phx-click='remove_session'][phx-value-sid='#{sess.id}']")
      |> render_click()

      html = render(view)
      refute html =~ "Delete me"
    end
  end
end
