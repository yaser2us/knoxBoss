defmodule AuthService.Guardian do
  @moduledoc """
  Guardian implementation for JWT token management in distributed systems.
  
  This module provides:
  - JWT token generation and validation
  - Secure token signing with rotating keys
  - Integration with distributed token cluster
  - Custom claims for authorization
  """
  
  use Guardian, otp_app: :auth_service
  
  alias AuthService.Accounts
  require Logger
  
  @doc """
  Generate the subject (sub) claim for JWT tokens.
  """
  def subject_for_token(user, _claims) do
    {:ok, to_string(user.id)}
  end
  
  @doc """
  Find the user resource from the subject claim.
  """
  def resource_from_claims(%{"sub" => id}) do
    case Accounts.get_user(id) do
      nil -> {:error, :resource_not_found}
      user -> {:ok, user}
    end
  end
  
  def resource_from_claims(_claims) do
    {:error, :invalid_claims}
  end
  
  @doc """
  Generate custom claims for the token.
  """
  def build_claims(claims, user, _opts) do
    custom_claims = %{
      "user_id" => user.id,
      "email" => user.email,
      "roles" => user.roles || [],
      "permissions" => user.permissions || [],
      "node" => to_string(Node.self()),
      "version" => "1.0"
    }
    
    {:ok, Map.merge(claims, custom_claims)}
  end
  
  @doc """
  Create a token with additional security features.
  """
  def create_token(user, claims \\ %{}, opts \\ []) do
    # Add security claims
    security_claims = %{
      "ip" => get_client_ip(opts),
      "user_agent" => get_user_agent(opts),
      "scope" => get_scope(opts),
      "device_id" => get_device_id(opts)
    }
    
    final_claims = Map.merge(claims, security_claims)
    
    case encode_and_sign(user, final_claims, opts) do
      {:ok, token, full_claims} ->
        # Log token creation
        Logger.info("Token created for user #{user.id}", %{
          user_id: user.id,
          jti: full_claims["jti"],
          node: Node.self()
        })
        
        {:ok, token, full_claims}
      
      error ->
        error
    end
  end
  
  @doc """
  Validate a token with additional security checks.
  """
  def validate_token(token, opts \\ []) do
    case decode_and_verify(token, opts) do
      {:ok, claims} ->
        # Additional security validation
        case perform_security_checks(claims, opts) do
          :ok ->
            {:ok, claims}
          {:error, reason} ->
            Logger.warn("Token security validation failed: #{reason}", %{
              jti: claims["jti"],
              reason: reason
            })
            {:error, reason}
        end
      
      error ->
        error
    end
  end
  
  @doc """
  Refresh a token with the same claims but new expiration.
  """
  def refresh_token(token, opts \\ []) do
    case decode_and_verify(token, opts) do
      {:ok, claims} ->
        case resource_from_claims(claims) do
          {:ok, user} ->
            # Create new token with same claims but fresh expiration
            new_claims = Map.drop(claims, ["exp", "iat", "jti"])
            create_token(user, new_claims, opts)
          
          error ->
            error
        end
      
      error ->
        error
    end
  end
  
  @doc """
  Generate a secure API key for service-to-service communication.
  """
  def generate_api_key(service_name, permissions \\ []) do
    claims = %{
      "service" => service_name,
      "permissions" => permissions,
      "type" => "api_key",
      "node" => to_string(Node.self())
    }
    
    # API keys have longer expiration
    opts = [ttl: {30, :day}]
    
    case encode_and_sign(%{id: service_name, type: :service}, claims, opts) do
      {:ok, token, full_claims} ->
        Logger.info("API key generated for service #{service_name}")
        {:ok, token, full_claims}
      
      error ->
        error
    end
  end
  
  @doc """
  Validate an API key.
  """
  def validate_api_key(api_key, required_permissions \\ []) do
    case decode_and_verify(api_key) do
      {:ok, claims} ->
        if claims["type"] == "api_key" do
          case check_permissions(claims["permissions"], required_permissions) do
            :ok ->
              {:ok, claims}
            {:error, reason} ->
              {:error, reason}
          end
        else
          {:error, :invalid_api_key}
        end
      
      error ->
        error
    end
  end
  
  # Private Functions
  
  defp perform_security_checks(claims, opts) do
    with :ok <- check_ip_address(claims, opts),
         :ok <- check_user_agent(claims, opts),
         :ok <- check_device_id(claims, opts),
         :ok <- check_token_age(claims) do
      :ok
    else
      error -> error
    end
  end
  
  defp check_ip_address(claims, opts) do
    current_ip = get_client_ip(opts)
    token_ip = claims["ip"]
    
    if current_ip && token_ip && current_ip != token_ip do
      {:error, :ip_mismatch}
    else
      :ok
    end
  end
  
  defp check_user_agent(claims, opts) do
    current_ua = get_user_agent(opts)
    token_ua = claims["user_agent"]
    
    if current_ua && token_ua && current_ua != token_ua do
      {:error, :user_agent_mismatch}
    else
      :ok
    end
  end
  
  defp check_device_id(claims, opts) do
    current_device = get_device_id(opts)
    token_device = claims["device_id"]
    
    if current_device && token_device && current_device != token_device do
      {:error, :device_mismatch}
    else
      :ok
    end
  end
  
  defp check_token_age(claims) do
    issued_at = claims["iat"]
    max_age = Application.get_env(:auth_service, :max_token_age, 86400) # 24 hours
    
    if System.system_time(:second) - issued_at > max_age do
      {:error, :token_too_old}
    else
      :ok
    end
  end
  
  defp check_permissions(user_permissions, required_permissions) do
    if Enum.all?(required_permissions, &(&1 in user_permissions)) do
      :ok
    else
      {:error, :insufficient_permissions}
    end
  end
  
  defp get_client_ip(opts) do
    opts[:client_ip] || opts[:remote_ip]
  end
  
  defp get_user_agent(opts) do
    opts[:user_agent]
  end
  
  defp get_scope(opts) do
    opts[:scope] || "default"
  end
  
  defp get_device_id(opts) do
    opts[:device_id]
  end
end