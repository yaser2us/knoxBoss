defmodule AuthService.Phoenix.AuthView do
  @moduledoc """
  View module for authentication responses.
  """
  
  # Phoenix 1.7+ doesn't use Phoenix.View
  # Views are now just modules with render functions

  def render("auth_success.json", %{user: user, token: token, session: session, expires_at: expires_at}) do
    %{
      success: true,
      data: %{
        user: render_user(user),
        token: token,
        session_id: session.id,
        expires_at: expires_at
      },
      timestamp: DateTime.utc_now()
    }
  end
  
  def render("login_success.json", %{user: user, token: token, session: session, expires_at: expires_at}) do
    %{
      success: true,
      data: %{
        user: render_user(user),
        token: token,
        session_id: session.id,
        expires_at: expires_at,
        last_login: user.last_login_at
      },
      timestamp: DateTime.utc_now()
    }
  end
  
  def render("user.json", %{user: user}) do
    %{
      success: true,
      data: %{
        user: render_user(user)
      },
      timestamp: DateTime.utc_now()
    }
  end
  
  def render("token_validation.json", %{user: user, claims: claims}) do
    %{
      success: true,
      data: %{
        valid: true,
        user: render_user(user),
        claims: claims,
        node: claims["node"]
      },
      timestamp: DateTime.utc_now()
    }
  end
  
  def render("logout_success.json", %{}) do
    %{
      success: true,
      message: "Successfully logged out",
      timestamp: DateTime.utc_now()
    }
  end
  
  def render("password_reset_sent.json", %{}) do
    %{
      success: true,
      message: "Password reset instructions sent to your email",
      timestamp: DateTime.utc_now()
    }
  end
  
  def render("password_reset_success.json", %{}) do
    %{
      success: true,
      message: "Password reset successfully",
      timestamp: DateTime.utc_now()
    }
  end
  
  def render("email_verification_sent.json", %{}) do
    %{
      success: true,
      message: "Email verification sent",
      timestamp: DateTime.utc_now()
    }
  end
  
  def render("email_verified.json", %{user: user}) do
    %{
      success: true,
      data: %{
        user: render_user(user),
        message: "Email verified successfully"
      },
      timestamp: DateTime.utc_now()
    }
  end
  
  def render("sessions.json", %{sessions: sessions}) do
    %{
      success: true,
      data: %{
        sessions: Enum.map(sessions, &render_session/1)
      },
      timestamp: DateTime.utc_now()
    }
  end
  
  def render("session_terminated.json", %{}) do
    %{
      success: true,
      message: "Session terminated successfully",
      timestamp: DateTime.utc_now()
    }
  end
  
  def render("profile_updated.json", %{user: user}) do
    %{
      success: true,
      data: %{
        user: render_user(user),
        message: "Profile updated successfully"
      },
      timestamp: DateTime.utc_now()
    }
  end
  
  def render("password_changed.json", %{}) do
    %{
      success: true,
      message: "Password changed successfully",
      timestamp: DateTime.utc_now()
    }
  end
  
  def render("users.json", %{users: users, pagination: pagination}) do
    %{
      success: true,
      data: %{
        users: Enum.map(users, &render_user/1),
        pagination: pagination
      },
      timestamp: DateTime.utc_now()
    }
  end
  
  def render("auth_stats.json", %{stats: stats}) do
    %{
      success: true,
      data: stats,
      timestamp: DateTime.utc_now()
    }
  end
  
  # Private helper functions
  defp render_user(user) do
    %{
      id: user.id,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      roles: user.roles,
      permissions: user.permissions,
      email_verified: user.email_verified,
      last_login_at: user.last_login_at,
      created_at: user.inserted_at,
      updated_at: user.updated_at
    }
  end
  
  defp render_session(session) do
    %{
      id: session.id,
      device_id: session.device_id,
      ip_address: session.ip_address,
      user_agent: session.user_agent,
      created_at: session.created_at,
      last_activity: session.last_activity,
      expires_at: session.expires_at
    }
  end
end