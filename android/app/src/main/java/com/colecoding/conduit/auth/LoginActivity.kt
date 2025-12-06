package com.colecoding.conduit.auth

import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.colecoding.conduit.BuildConfig
import com.colecoding.conduit.MainActivity
import com.colecoding.conduit.config.AppConfig
import com.colecoding.conduit.databinding.ActivityLoginBinding
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInAccount
import com.google.android.gms.auth.api.signin.GoogleSignInClient
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.ApiException
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject

class LoginActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "LoginActivity"
    }

    private lateinit var binding: ActivityLoginBinding
    private lateinit var googleSignInClient: GoogleSignInClient

    private val googleSignInLauncher =
            registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
                Log.d(TAG, "Google Sign-In result received, resultCode: ${result.resultCode}")
                val task = GoogleSignIn.getSignedInAccountFromIntent(result.data)
                try {
                    val account = task.getResult(ApiException::class.java)
                    Log.d(TAG, "Google Sign-In successful, account: ${account?.email}")
                    account?.let { handleGoogleSignIn(it) }
                } catch (e: ApiException) {
                    Log.e(
                            TAG,
                            "Google sign in failed with code: ${e.statusCode}, message: ${e.message}",
                            e
                    )
                    showLoading(false)
                    Toast.makeText(
                                    this,
                                    "Google sign in failed: ${e.statusCode}",
                                    Toast.LENGTH_SHORT
                            )
                            .show()
                }
            }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        binding = ActivityLoginBinding.inflate(layoutInflater)
        setContentView(binding.root)

        setupGoogleSignIn()
        setupClickListeners()
    }

    private fun setupGoogleSignIn() {
        // Note: Temporarily removing requestIdToken until OAuth client is configured in Firebase
        val gso =
                GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
                        .requestEmail()
                        .requestProfile()
                        // Use BuildConfig for Google Client ID
                        .requestIdToken(BuildConfig.GOOGLE_CLIENT_ID)
                        .build()

        googleSignInClient = GoogleSignIn.getClient(this, gso)
    }

    private fun setupClickListeners() {
        binding.btnLogin.setOnClickListener {
            val email = binding.etEmail.text.toString()
            val password = binding.etPassword.text.toString()

            if (email.isBlank() || password.isBlank()) {
                Toast.makeText(this, "Please enter email and password", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            performLogin(email, password)
        }

        binding.btnGoogleSignIn.setOnClickListener { signInWithGoogle() }
    }

    private fun performLogin(email: String, password: String) {
        showLoading(true)

        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val url = URL("${AppConfig.getBaseUrl(this@LoginActivity)}/api/v1/login")
                val connection = url.openConnection() as HttpURLConnection

                connection.apply {
                    requestMethod = "POST"
                    doOutput = true
                    setRequestProperty("Content-Type", "application/json")
                    setRequestProperty("Accept", "application/json")
                }

                val json =
                        JSONObject().apply {
                            put("email", email)
                            put("password", password)
                        }

                OutputStreamWriter(connection.outputStream).use { it.write(json.toString()) }

                val responseCode = connection.responseCode
                if (responseCode == HttpURLConnection.HTTP_OK) {
                    val response =
                            BufferedReader(InputStreamReader(connection.inputStream)).use {
                                it.readText()
                            }

                    val jsonResponse = JSONObject(response)
                    handleLoginSuccess(jsonResponse)
                } else {
                    val error =
                            BufferedReader(InputStreamReader(connection.errorStream)).use {
                                it.readText()
                            }
                    withContext(Dispatchers.Main) {
                        showLoading(false)
                        Toast.makeText(this@LoginActivity, "Login failed", Toast.LENGTH_SHORT)
                                .show()
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Login error", e)
                withContext(Dispatchers.Main) {
                    showLoading(false)
                    Toast.makeText(
                                    this@LoginActivity,
                                    "Network error: ${e.message}",
                                    Toast.LENGTH_SHORT
                            )
                            .show()
                }
            }
        }
    }

    private fun signInWithGoogle() {
        Log.d(TAG, "Initiating Google Sign-In")
        showLoading(true)
        val signInIntent = googleSignInClient.signInIntent
        googleSignInLauncher.launch(signInIntent)
    }

    private fun handleGoogleSignIn(account: GoogleSignInAccount) {
        Log.d(TAG, "Handling Google Sign-In for account: ${account.email}")
        Log.d(TAG, "ID Token present: ${account.idToken != null}")
        showLoading(true)

        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val url = URL("${AppConfig.getBaseUrl(this@LoginActivity)}/api/v1/google_auth")
                Log.d(TAG, "Sending Google auth request to: $url")
                val connection = url.openConnection() as HttpURLConnection

                connection.apply {
                    requestMethod = "POST"
                    doOutput = true
                    setRequestProperty("Content-Type", "application/json")
                    setRequestProperty("Accept", "application/json")
                }

                val json =
                        JSONObject().apply {
                            put("email", account.email)
                            put("name", account.displayName)
                            put("image_url", account.photoUrl?.toString())
                            // Include ID token for secure authentication
                            put("id_token", account.idToken)
                        }

                OutputStreamWriter(connection.outputStream).use { it.write(json.toString()) }

                val responseCode = connection.responseCode
                if (responseCode == HttpURLConnection.HTTP_OK) {
                    val response =
                            BufferedReader(InputStreamReader(connection.inputStream)).use {
                                it.readText()
                            }

                    val jsonResponse = JSONObject(response)

                    withContext(Dispatchers.Main) { handleLoginSuccess(jsonResponse) }
                } else {
                    val errorResponse = BufferedReader(InputStreamReader(connection.errorStream)).use {
                        it.readText()
                    }
                    Log.e(TAG, "Google auth failed with code $responseCode: $errorResponse")

                    withContext(Dispatchers.Main) {
                        showLoading(false)
                        val errorMessage = try {
                            JSONObject(errorResponse).optString("error", "Google sign in failed")
                        } catch (e: Exception) {
                            "Google sign in failed"
                        }
                        Toast.makeText(
                                        this@LoginActivity,
                                        errorMessage,
                                        Toast.LENGTH_LONG
                                )
                                .show()
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Google sign in error", e)
                withContext(Dispatchers.Main) {
                    showLoading(false)
                    Toast.makeText(this@LoginActivity, "Network error", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    private fun handleLoginSuccess(response: JSONObject) {
        // Save authentication data
        val user = response.getJSONObject("user")
        val authToken = response.optString("auth_token")

        AuthManager.saveAuthData(
                this,
                userId = user.getString("id"),
                userName = user.getString("name"),
                userEmail = user.getString("email"),
                sessionCookie = response.optString("session_cookie", ""),
                authToken = authToken
        )

        // Log auth token for debugging
        if (authToken.isNotEmpty()) {
            Log.d(TAG, "Auth token received and saved")
        } else {
            Log.w(TAG, "No auth token in response")
        }

        // Navigate to main activity
        val intent = Intent(this, MainActivity::class.java)
        startActivity(intent)
        finish()
    }

    private fun showLoading(show: Boolean) {
        binding.progressBar.visibility = if (show) View.VISIBLE else View.GONE
        binding.btnLogin.isEnabled = !show
        binding.btnGoogleSignIn.isEnabled = !show
    }
}
