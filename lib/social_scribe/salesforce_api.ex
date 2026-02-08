defmodule SocialScribe.SalesforceApi do
  @moduledoc """
  Salesforce CRM API client for contacts operations.
  Implements automatic token refresh on 401/expired token errors.
  """

  alias SocialScribe.Accounts.UserCredential

  require Logger

  # Salesforce API version
  @api_version "v59.0"

  # Contact fields to query
  @contact_fields [
    "Id",
    "FirstName",
    "LastName",
    "Email",
    "Phone",
    "MobilePhone",
    "Title",
    "Department",
    "MailingStreet",
    "MailingCity",
    "MailingState",
    "MailingPostalCode",
    "MailingCountry",
    "Account.Name",
    "Description"
  ]

  defp client(access_token, instance_url) do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, instance_url},
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Headers,
       [
         {"Authorization", "Bearer #{access_token}"},
         {"Content-Type", "application/json"}
       ]}
    ])
  end

  @doc """
  Searches for contacts by query string using SOSL.
  Returns up to 10 matching contacts with basic properties.
  Automatically refreshes token on 401/expired errors and retries once.
  """
  def search_contacts(%UserCredential{} = credential, query) when is_binary(query) do
    with_token_refresh(credential, fn cred ->
      # Use SOQL with LIKE for searching
      # Escape single quotes in query
      safe_query = String.replace(query, "'", "\\'")

      soql = """
      SELECT #{Enum.join(@contact_fields, ", ")}
      FROM Contact
      WHERE FirstName LIKE '%#{safe_query}%'
         OR LastName LIKE '%#{safe_query}%'
         OR Email LIKE '%#{safe_query}%'
         OR Account.Name LIKE '%#{safe_query}%'
      LIMIT 10
      """

      encoded_query = URI.encode(String.trim(soql))
      url = "/services/data/#{@api_version}/query?q=#{encoded_query}"

      case Tesla.get(client(cred.token, cred.instance_url), url) do
        {:ok, %Tesla.Env{status: 200, body: %{"records" => records}}} ->
          contacts = Enum.map(records, &format_contact/1)
          {:ok, contacts}

        {:ok, %Tesla.Env{status: status, body: body}} ->
          {:error, {:api_error, status, body}}

        {:error, reason} ->
          {:error, {:http_error, reason}}
      end
    end)
  end

  @doc """
  Gets a single contact by ID with all properties.
  Automatically refreshes token on 401/expired errors and retries once.
  """
  def get_contact(%UserCredential{} = credential, contact_id) do
    with_token_refresh(credential, fn cred ->
      fields_param = Enum.join(@contact_fields, ",")
      url = "/services/data/#{@api_version}/sobjects/Contact/#{contact_id}?fields=#{fields_param}"

      case Tesla.get(client(cred.token, cred.instance_url), url) do
        {:ok, %Tesla.Env{status: 200, body: body}} ->
          {:ok, format_contact(body)}

        {:ok, %Tesla.Env{status: 404, body: _body}} ->
          {:error, :not_found}

        {:ok, %Tesla.Env{status: status, body: body}} ->
          {:error, {:api_error, status, body}}

        {:error, reason} ->
          {:error, {:http_error, reason}}
      end
    end)
  end

  @doc """
  Updates a contact's fields.
  `updates` should be a map of field names to new values.
  Automatically refreshes token on 401/expired errors and retries once.

  Note: Salesforce field names are case-sensitive (e.g., "FirstName", not "firstname")
  """
  def update_contact(%UserCredential{} = credential, contact_id, updates)
      when is_map(updates) do
    with_token_refresh(credential, fn cred ->
      url = "/services/data/#{@api_version}/sobjects/Contact/#{contact_id}"

      case Tesla.patch(client(cred.token, cred.instance_url), url, updates) do
        {:ok, %Tesla.Env{status: status}} when status in [200, 204] ->
          # Salesforce returns 204 No Content on successful PATCH
          # Fetch the updated contact to return
          get_contact(credential, contact_id)

        {:ok, %Tesla.Env{status: 404, body: _body}} ->
          {:error, :not_found}

        {:ok, %Tesla.Env{status: status, body: body}} ->
          {:error, {:api_error, status, body}}

        {:error, reason} ->
          {:error, {:http_error, reason}}
      end
    end)
  end

  @doc """
  Batch updates multiple fields on a contact.
  This is a convenience wrapper around update_contact/3.

  `updates_list` should be a list of maps with :field, :new_value, and :apply keys.
  Only updates where :apply is true will be applied.
  """
  def apply_updates(%UserCredential{} = credential, contact_id, updates_list)
      when is_list(updates_list) do
    updates_map =
      updates_list
      |> Enum.filter(fn update -> update[:apply] == true end)
      |> Enum.reduce(%{}, fn update, acc ->
        # Map our internal field names to Salesforce field names
        sf_field = map_field_to_salesforce(update.field)
        Map.put(acc, sf_field, update.new_value)
      end)

    if map_size(updates_map) > 0 do
      update_contact(credential, contact_id, updates_map)
    else
      {:ok, :no_updates}
    end
  end

  @doc """
  Searches for contacts by email address.
  Useful for finding meeting attendees.
  """
  def search_contacts_by_email(%UserCredential{} = credential, email) when is_binary(email) do
    with_token_refresh(credential, fn cred ->
      safe_email = String.replace(email, "'", "\\'")

      soql = """
      SELECT #{Enum.join(@contact_fields, ", ")}
      FROM Contact
      WHERE Email = '#{safe_email}'
      LIMIT 5
      """

      encoded_query = URI.encode(String.trim(soql))
      url = "/services/data/#{@api_version}/query?q=#{encoded_query}"

      case Tesla.get(client(cred.token, cred.instance_url), url) do
        {:ok, %Tesla.Env{status: 200, body: %{"records" => records}}} ->
          contacts = Enum.map(records, &format_contact/1)
          {:ok, contacts}

        {:ok, %Tesla.Env{status: status, body: body}} ->
          {:error, {:api_error, status, body}}

        {:error, reason} ->
          {:error, {:http_error, reason}}
      end
    end)
  end

  # Format a Salesforce contact response into a cleaner structure
  # Matches the format used by HubSpot API for consistency
  defp format_contact(%{"Id" => id} = contact) do
    account_name = get_in(contact, ["Account", "Name"])

    %{
      id: id,
      firstname: contact["FirstName"],
      lastname: contact["LastName"],
      email: contact["Email"],
      phone: contact["Phone"],
      mobilephone: contact["MobilePhone"],
      company: account_name,
      jobtitle: contact["Title"],
      department: contact["Department"],
      address: contact["MailingStreet"],
      city: contact["MailingCity"],
      state: contact["MailingState"],
      zip: contact["MailingPostalCode"],
      country: contact["MailingCountry"],
      description: contact["Description"],
      display_name: format_display_name(contact)
    }
  end

  defp format_contact(_), do: nil

  defp format_display_name(contact) do
    firstname = contact["FirstName"] || ""
    lastname = contact["LastName"] || ""
    email = contact["Email"] || ""

    name = String.trim("#{firstname} #{lastname}")

    if name == "" do
      email
    else
      name
    end
  end

  # Map internal field names to Salesforce API field names
  defp map_field_to_salesforce(field) do
    case field do
      "firstname" -> "FirstName"
      "lastname" -> "LastName"
      "email" -> "Email"
      "phone" -> "Phone"
      "mobilephone" -> "MobilePhone"
      "jobtitle" -> "Title"
      "department" -> "Department"
      "address" -> "MailingStreet"
      "city" -> "MailingCity"
      "state" -> "MailingState"
      "zip" -> "MailingPostalCode"
      "country" -> "MailingCountry"
      "description" -> "Description"
      # Pass through if already in Salesforce format
      other -> other
    end
  end

  # Wrapper that handles token refresh on auth errors
  # Tries the API call, and if it fails with 401, refreshes token and retries once
  defp with_token_refresh(%UserCredential{} = credential, api_call) do
    alias SocialScribe.SalesforceTokenRefresher

    with {:ok, credential} <- SalesforceTokenRefresher.ensure_valid_token(credential) do
      case api_call.(credential) do
        {:error, {:api_error, 401, _body}} ->
          Logger.info("Salesforce token expired, refreshing and retrying...")
          retry_with_fresh_token(credential, api_call)

        {:error, {:api_error, status, body}} when is_list(body) ->
          # Salesforce returns errors as a list
          if is_token_error?(body) do
            Logger.info("Salesforce token error, refreshing and retrying...")
            retry_with_fresh_token(credential, api_call)
          else
            Logger.error("Salesforce API error: #{status} - #{inspect(body)}")
            {:error, {:api_error, status, body}}
          end

        other ->
          other
      end
    end
  end

  defp retry_with_fresh_token(credential, api_call) do
    alias SocialScribe.SalesforceTokenRefresher

    case SalesforceTokenRefresher.refresh_credential(credential) do
      {:ok, refreshed_credential} ->
        case api_call.(refreshed_credential) do
          {:error, {:api_error, status, body}} ->
            Logger.error("Salesforce API error after refresh: #{status} - #{inspect(body)}")
            {:error, {:api_error, status, body}}

          {:error, {:http_error, reason}} ->
            Logger.error("Salesforce HTTP error after refresh: #{inspect(reason)}")
            {:error, {:http_error, reason}}

          success ->
            success
        end

      {:error, refresh_error} ->
        Logger.error("Failed to refresh Salesforce token: #{inspect(refresh_error)}")
        {:error, {:token_refresh_failed, refresh_error}}
    end
  end

  defp is_token_error?(errors) when is_list(errors) do
    Enum.any?(errors, fn error ->
      error_code = error["errorCode"] || ""
      message = error["message"] || ""

      error_code in ["INVALID_SESSION_ID", "INVALID_AUTH_HEADER"] ||
        String.contains?(String.downcase(message), ["session", "expired", "invalid"])
    end)
  end

  defp is_token_error?(_), do: false
end
