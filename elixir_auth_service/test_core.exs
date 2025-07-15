#!/usr/bin/env elixir

# Direct test of the core authentication functions
IO.puts("🧪 Testing Core Authentication Functions...")

# Test the User model directly
test_user_params = %{
  "email" => "direct@example.com",
  "password" => "Test123!@#",
  "first_name" => "Direct",
  "last_name" => "Test"
}

IO.puts("\n1. Testing User changeset creation...")
result = try do
  # Load the application context
  Mix.Task.run("app.start")
  
  # Test user creation
  changeset = AuthService.Accounts.User.registration_changeset(%AuthService.Accounts.User{}, test_user_params)
  
  if changeset.valid? do
    IO.puts("✅ User changeset is valid!")
    IO.puts("   - Email: #{changeset.changes.email}")
    IO.puts("   - First name: #{changeset.changes.first_name}")
    IO.puts("   - Last name: #{changeset.changes.last_name}")
    IO.puts("   - Password hash: #{String.slice(changeset.changes.password_hash, 0, 20)}...")
    
    # Test password verification
    IO.puts("\n2. Testing password verification...")
    test_password = "Test123!@#"
    stored_hash = changeset.changes.password_hash
    
    if Bcrypt.verify_pass(test_password, stored_hash) do
      IO.puts("✅ Password verification successful!")
    else
      IO.puts("❌ Password verification failed!")
    end
    
    # Test wrong password
    if Bcrypt.verify_pass("wrongpassword", stored_hash) do
      IO.puts("❌ Wrong password incorrectly verified!")
    else
      IO.puts("✅ Wrong password correctly rejected!")
    end
    
    true
  else
    IO.puts("❌ User changeset is invalid!")
    IO.puts("   Errors: #{inspect(changeset.errors)}")
    false
  end
rescue
  error ->
    IO.puts("❌ Error during test: #{inspect(error)}")
    false
end

if result do
  IO.puts("\n🎉 Core authentication functions are working correctly!")
else
  IO.puts("\n❌ Core authentication functions have issues!")
end