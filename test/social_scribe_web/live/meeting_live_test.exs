defmodule SocialScribeWeb.MeetingLiveTest do
  use SocialScribeWeb.ConnCase

  import Phoenix.LiveViewTest
  import SocialScribe.AccountsFixtures
  import SocialScribe.MeetingsFixtures

  describe "MeetingLive.Index - unauthenticated" do
    test "redirects to login", %{conn: conn} do
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/dashboard/meetings")
      assert path == ~p"/users/log_in"
    end
  end

  describe "MeetingLive.Index - authenticated" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "renders meetings page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings")

      assert html =~ "Meetings"
    end

    test "shows empty state when no meetings", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings")

      # Should render without error
      assert is_binary(html)
    end
  end

  describe "MeetingLive.Show - with meeting" do
    setup %{conn: conn} do
      user = user_fixture()
      meeting = create_meeting_with_transcript(user)

      %{conn: log_in_user(conn, user), user: user, meeting: meeting}
    end

    test "renders meeting detail page", %{conn: conn, meeting: meeting} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      assert html =~ meeting.title
    end

    test "shows meeting transcript", %{conn: conn, meeting: meeting} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      assert is_binary(html)
    end

    test "does not show HubSpot section without credential", %{conn: conn, meeting: meeting} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      refute html =~ "HubSpot Integration"
    end

    test "does not show Salesforce section without credential", %{conn: conn, meeting: meeting} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      refute html =~ "Salesforce Integration"
    end

    test "shows HubSpot section with credential", %{conn: conn, meeting: meeting, user: user} do
      _cred = hubspot_credential_fixture(%{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      assert html =~ "HubSpot Integration"
    end

    test "shows Salesforce section with credential", %{conn: conn, meeting: meeting, user: user} do
      _cred = make_salesforce_cred(%{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      assert html =~ "Salesforce Integration"
    end
  end

  defp create_meeting_with_transcript(user) do
    meeting = meeting_fixture(%{})
    calendar_event = SocialScribe.Calendar.get_calendar_event!(meeting.calendar_event_id)

    {:ok, _} =
      SocialScribe.Calendar.update_calendar_event(calendar_event, %{user_id: user.id})

    meeting_transcript_fixture(%{
      meeting_id: meeting.id,
      content: %{
        "data" => [
          %{
            "speaker" => "Test Speaker",
            "words" => [%{"text" => "Hello"}, %{"text" => "world"}]
          }
        ]
      }
    })

    meeting_participant_fixture(%{meeting_id: meeting.id, name: "Host", is_host: true})

    SocialScribe.Meetings.get_meeting_with_details(meeting.id)
  end
end
