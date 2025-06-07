# Community Hub Application

A Rails application for managing community resources, tools, and communication.

## Setup

### Prerequisites

* Ruby 3.2.0 or higher
* PostgreSQL
* Node.js and Yarn

### Installation

1. Clone the repository
2. Run `bundle install` to install Ruby dependencies
3. Run `rails db:create db:migrate` to set up the database
4. Start the server with `bin/dev`

## Google OAuth Setup

This application uses Google OAuth for authentication. To set it up:

1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Navigate to "APIs & Services" > "Credentials"
4. Click "Create Credentials" and select "OAuth client ID"
5. Select "Web application" as the application type
6. Add your application's domain to the "Authorized JavaScript origins" (e.g., `http://localhost:3000`)
7. Add your callback URL to "Authorized redirect URIs" (e.g., `http://localhost:3000/auth/google_oauth2/callback`)
8. Click "Create" to generate your client ID and client secret
9. Set the following environment variables in your development environment:
   ```
   GOOGLE_CLIENT_ID=your_client_id
   GOOGLE_CLIENT_SECRET=your_client_secret
   ```

You can set these environment variables using a `.env` file with the `dotenv-rails` gem, or by adding them to your shell
environment.

### Troubleshooting

If you encounter a "Missing required parameter: client_id" error when trying to log in with Google:

1. Make sure you have created a `.env` file in the root of your project
2. Ensure your `.env` file contains the following lines with your actual credentials:
   ```
   GOOGLE_CLIENT_ID=your_actual_client_id_from_google_cloud_console
   GOOGLE_CLIENT_SECRET=your_actual_client_secret_from_google_cloud_console
   ```
3. Restart your Rails server after adding or updating the `.env` file
4. If you're still having issues, try visiting `/test/env` in your browser to verify that the environment variables are
   being loaded correctly

## Features

* User authentication with Google OAuth
* Community dashboard
* Tool sharing and management
* Kitchen inventory tracking
* Common house booking system
