defmodule AuthService.DevController do
  @moduledoc """
  Development controller for development environment only.
  """
  
  use Phoenix.Controller, namespace: AuthService
  
  @doc """
  Development info endpoint.
  """
  def info(conn, _params) do
    info = %{
      application: "AuthService",
      version: Application.spec(:auth_service, :vsn) |> to_string(),
      environment: Mix.env(),
      node: Node.self(),
      timestamp: DateTime.utc_now(),
      endpoints: %{
        health: "/health",
        metrics: "/metrics",
        auth_api: "/api/v1/auth/*",
        admin_api: "/api/v1/admin/*"
      }
    }
    
    json(conn, info)
  end
end