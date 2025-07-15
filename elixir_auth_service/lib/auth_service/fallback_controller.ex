defmodule AuthService.FallbackController do
  @moduledoc """
  Fallback controller for handling unmatched routes and errors.
  """
  
  use Phoenix.Controller, namespace: AuthService
  
  @doc """
  Handle 404 Not Found for unmatched routes.
  """
  def not_found(conn, _params) do
    conn
    |> put_status(:not_found)
    |> json(%{
      error: "Not Found",
      message: "The requested resource was not found",
      path: conn.request_path,
      method: conn.method,
      timestamp: DateTime.utc_now()
    })
  end
  
  @doc """
  Handle validation errors from changesets.
  """
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      error: "Validation Error",
      details: translate_errors(changeset),
      timestamp: DateTime.utc_now()
    })
  end
  
  @doc """
  Handle authentication errors.
  """
  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{
      error: "Unauthorized",
      message: "Authentication required",
      timestamp: DateTime.utc_now()
    })
  end
  
  @doc """
  Handle forbidden errors.
  """
  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> json(%{
      error: "Forbidden",
      message: "Access denied",
      timestamp: DateTime.utc_now()
    })
  end
  
  @doc """
  Handle not found errors.
  """
  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> json(%{
      error: "Not Found",
      message: "Resource not found",
      timestamp: DateTime.utc_now()
    })
  end
  
  @doc """
  Handle rate limiting errors.
  """
  def call(conn, {:error, :rate_limited}) do
    conn
    |> put_status(:too_many_requests)
    |> json(%{
      error: "Too Many Requests",
      message: "Rate limit exceeded",
      timestamp: DateTime.utc_now()
    })
  end
  
  @doc """
  Handle account locked errors.
  """
  def call(conn, {:error, :account_locked}) do
    conn
    |> put_status(:locked)
    |> json(%{
      error: "Account Locked",
      message: "Account has been temporarily locked due to too many failed login attempts",
      timestamp: DateTime.utc_now()
    })
  end
  
  @doc """
  Handle invalid credentials errors.
  """
  def call(conn, {:error, :invalid_credentials}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{
      error: "Invalid Credentials",
      message: "Email or password is incorrect",
      timestamp: DateTime.utc_now()
    })
  end
  
  @doc """
  Handle token errors.
  """
  def call(conn, {:error, :invalid_token}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{
      error: "Invalid Token",
      message: "The provided token is invalid or expired",
      timestamp: DateTime.utc_now()
    })
  end
  
  @doc """
  Handle generic errors with custom messages.
  """
  def call(conn, {:error, message}) when is_binary(message) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      error: "Bad Request",
      message: message,
      timestamp: DateTime.utc_now()
    })
  end
  
  @doc """
  Handle any other errors.
  """
  def call(conn, error) do
    require Logger
    Logger.error("Unhandled error in fallback controller: #{inspect(error)}")
    
    conn
    |> put_status(:internal_server_error)
    |> json(%{
      error: "Internal Server Error",
      message: "An unexpected error occurred",
      timestamp: DateTime.utc_now()
    })
  end
  
  # Helper function to translate changeset errors
  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end