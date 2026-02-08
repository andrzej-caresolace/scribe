defmodule SocialScribe.CrmCopilot.Turn do
  @moduledoc "A single exchange (human or copilot) within a copilot session."

  use Ecto.Schema
  import Ecto.Changeset

  @valid_senders ["human", "copilot"]

  schema "copilot_turns" do
    field :sender, :string
    field :body, :string
    field :extras, :map, default: %{}

    belongs_to :session, SocialScribe.CrmCopilot.Session

    timestamps(type: :utc_datetime)
  end

  @required ~w(session_id sender body)a
  @optional ~w(extras)a

  def changeset(turn, params) do
    turn
    |> cast(params, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:sender, @valid_senders)
    |> foreign_key_constraint(:session_id)
  end

  def valid_senders, do: @valid_senders
end
