defmodule AuthService.GuardianSerializer do
  @moduledoc """
  Guardian serializer for handling user authentication tokens.
  
  This module defines how to serialize and deserialize users
  to/from JWT tokens for authentication purposes.
  """
  
  @behaviour Guardian.Serializer
  
  alias AuthService.{Accounts, Accounts.User}
  
  @doc """
  Serialize a user resource into a token subject.
  
  Takes a user struct and returns a tuple with the resource type
  and the user's ID for inclusion in the JWT token.
  """
  def for_token(%User{id: id}), do: {:ok, "User:#{id}"}
  def for_token(_), do: {:error, "Unknown resource type"}
  
  @doc """
  Deserialize a token subject back into a user resource.
  
  Takes a token subject (like "User:123") and returns the
  corresponding user struct from the database.
  """
  def from_token("User:" <> id) do
    case Accounts.get_user(id) do
      %User{} = user -> {:ok, user}
      nil -> {:error, "User not found"}
    end
  rescue
    Ecto.Query.CastError -> {:error, "Invalid user ID format"}
    _ -> {:error, "Database error"}
  end
  
  def from_token(_), do: {:error, "Unknown token subject"}
end