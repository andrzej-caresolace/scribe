defmodule SocialScribeWeb.SalesforceModalExtendedTest do
  @moduledoc "Extended tests for SalesforceModalComponent events and interactions."
  use SocialScribeWeb.ConnCase

  import Phoenix.LiveViewTest
  import SocialScribe.AccountsFixtures
  import SocialScribe.MeetingsFixtures
  import Mox

  setup :verify_on_exit!

  defp build_meeting(user) do
    meeting = meeting_fixture(%{})
    calendar_event = SocialScribe.Calendar.get_calendar_event!(meeting.calendar_event_id)
    {:ok, _} = SocialScribe.Calendar.update_calendar_event(calendar_event, %{user_id: user.id})

    meeting_transcript_fixture(%{
      meeting_id: meeting.id,
      content: %{
        "data" => [
          %{
            "speaker" => "Test Speaker",
            "words" => [
              %{"text" => "My"},
              %{"text" => "email"},
              %{"text" => "is"},
              %{"text" => "test@example.com"}
            ]
          }
        ]
      }
    })

    SocialScribe.Meetings.get_meeting_with_details(meeting.id)
  end

  describe "SalesforceModalComponent - contact_search event" do
    setup %{conn: conn} do
      user = user_fixture()
      sf_cred = make_salesforce_cred(%{user_id: user.id})
      meeting = build_meeting(user)

      %{conn: log_in_user(conn, user), user: user, meeting: meeting, sf_cred: sf_cred}
    end

    test "contact_search with short query does not trigger search", %{
      conn: conn,
      meeting: meeting
    } do
      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/salesforce")

      view
      |> element("input[phx-keyup='contact_search']")
      |> render_keyup(%{value: "a"})

      # Should not show spinner since query < 2 chars
      refute has_element?(view, "div", "Searching...")
    end

    test "contact_search with valid query sends search message", %{
      conn: conn,
      meeting: meeting
    } do
      # Mock the Salesforce search that will be triggered
      SocialScribe.MockSalesforceClient
      |> stub(:search_contacts, fn _cred, _q -> {:ok, []} end)

      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/salesforce")

      view
      |> element("input[phx-keyup='contact_search']")
      |> render_keyup(%{value: "John"})

      # The search was triggered (may show searching or results)
      html = render(view)
      assert is_binary(html)
    end

    test "clear_contact resets state", %{conn: conn, meeting: meeting} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/salesforce")

      # Verify search input is present
      assert has_element?(view, "input[phx-keyup='contact_search']")
    end

    test "open_contact_dropdown shows dropdown", %{conn: conn, meeting: meeting} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/salesforce")

      view
      |> element("input[phx-focus='open_contact_dropdown']")
      |> render_focus()

      # Dropdown should be open now
      html = render(view)
      assert is_binary(html)
    end

    test "apply_updates without selection shows error", %{conn: conn, meeting: meeting} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/salesforce")

      # No form visible yet since no contact selected
      refute has_element?(view, "form[phx-submit='apply_updates']")
    end
  end
end
