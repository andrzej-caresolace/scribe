defmodule SocialScribe.CrmCopilot do
  @moduledoc """
  Context for the AI copilot assistant.
  Manages sessions (threads) and turns (individual exchanges).
  """

  import Ecto.Query
  alias SocialScribe.Repo
  alias SocialScribe.CrmCopilot.{Session, Turn}

  # ── Sessions ──────────────────────────────────────────────

  def start_session(params) do
    %Session{} |> Session.changeset(params) |> Repo.insert()
  end

  def sessions_for_user(uid) do
    Session
    |> where([s], s.user_id == ^uid)
    |> order_by([s], desc: s.updated_at)
    |> Repo.all()
  end

  def load_session!(id) do
    Session
    |> Repo.get!(id)
    |> Repo.preload(turns: from(t in Turn, order_by: [asc: t.inserted_at]))
  end

  def fetch_session!(id), do: Repo.get!(Session, id)

  def destroy_session(%Session{} = s), do: Repo.delete(s)

  # ── Turns ─────────────────────────────────────────────────

  def add_turn(params) do
    %Turn{} |> Turn.changeset(params) |> Repo.insert()
  end

  def turns_for_session(session_id) do
    Turn
    |> where([t], t.session_id == ^session_id)
    |> order_by([t], asc: t.inserted_at)
    |> Repo.all()
  end
end
