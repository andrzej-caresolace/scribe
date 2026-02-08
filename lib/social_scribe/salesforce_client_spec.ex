defmodule SocialScribe.SalesforceClientSpec do
  @moduledoc """
  Defines the contract for Salesforce API operations.
  Production code delegates to `SalesforceApi`; tests swap in a Mox mock.
  """

  alias SocialScribe.Accounts.UserCredential

  @type credential :: UserCredential.t()
  @type api_ok(t) :: {:ok, t} | {:error, term()}

  @callback search_contacts(credential(), binary()) :: api_ok(list(map()))
  @callback get_contact(credential(), binary()) :: api_ok(map())
  @callback update_contact(credential(), binary(), map()) :: api_ok(map())
  @callback apply_updates(credential(), binary(), list(map())) :: api_ok(map() | :no_updates)
  @callback create_contact(credential(), map()) :: api_ok(map())

  # Dynamic dispatch helpers

  def search_contacts(cred, q), do: adapter().search_contacts(cred, q)
  def get_contact(cred, id), do: adapter().get_contact(cred, id)
  def update_contact(cred, id, patch), do: adapter().update_contact(cred, id, patch)
  def apply_updates(cred, id, ops), do: adapter().apply_updates(cred, id, ops)
  def create_contact(cred, props), do: adapter().create_contact(cred, props)

  defp adapter do
    Application.get_env(:social_scribe, :salesforce_client, SocialScribe.SalesforceApi)
  end
end
