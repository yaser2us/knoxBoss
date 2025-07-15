defmodule AuthService.Phoenix.ErrorView do
  @moduledoc """
  View module for error responses.
  """
  
  # Phoenix 1.7+ doesn't use Phoenix.View
  # Views are now just modules with render functions

  def render("error.json", %{changeset: changeset}) do
    %{
      success: false,
      error: "Validation Error",
      details: translate_errors(changeset),
      timestamp: DateTime.utc_now()
    }
  end
  
  def render("error.json", %{message: message}) do
    %{
      success: false,
      error: message,
      timestamp: DateTime.utc_now()
    }
  end
  
  def render("unauthorized.json", %{}) do
    %{
      success: false,
      error: "Unauthorized",
      message: "Authentication required",
      timestamp: DateTime.utc_now()
    }
  end
  
  def render("forbidden.json", %{}) do
    %{
      success: false,
      error: "Forbidden",
      message: "Access denied",
      timestamp: DateTime.utc_now()
    }
  end
  
  def render("not_found.json", %{}) do
    %{
      success: false,
      error: "Not Found",
      message: "Resource not found",
      timestamp: DateTime.utc_now()
    }
  end
  
  def render("rate_limited.json", %{}) do
    %{
      success: false,
      error: "Too Many Requests",
      message: "Rate limit exceeded",
      timestamp: DateTime.utc_now()
    }
  end
  
  def render("account_locked.json", %{}) do
    %{
      success: false,
      error: "Account Locked",
      message: "Account has been temporarily locked due to too many failed login attempts",
      timestamp: DateTime.utc_now()
    }
  end
  
  def render("invalid_credentials.json", %{}) do
    %{
      success: false,
      error: "Invalid Credentials",
      message: "Email or password is incorrect",
      timestamp: DateTime.utc_now()
    }
  end
  
  def render("invalid_token.json", %{}) do
    %{
      success: false,
      error: "Invalid Token",
      message: "The provided token is invalid or expired",
      timestamp: DateTime.utc_now()
    }
  end
  
  def render("server_error.json", %{}) do
    %{
      success: false,
      error: "Internal Server Error",
      message: "An unexpected error occurred",
      timestamp: DateTime.utc_now()
    }
  end
  
  def render("bad_request.json", %{message: message}) do
    %{
      success: false,
      error: "Bad Request",
      message: message,
      timestamp: DateTime.utc_now()
    }
  end
  
  # Template not found
  def template_not_found(template, _assigns) do
    %{
      success: false,
      error: "Template Not Found",
      message: "Template #{template} not found",
      timestamp: DateTime.utc_now()
    }
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