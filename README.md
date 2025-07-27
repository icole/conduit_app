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

## Mailing List Configuration

The application includes a full-featured mailing list system with both web management and email forwarding capabilities.

### Setup

1. Set the domain and subdomain for your mailing lists by adding these environment variables:
   ```
   MAILING_LIST_DOMAIN=example.com
   MAILING_LIST_SUBDOMAIN=lists
   ```

2. This will generate email addresses in the format: `listname@subdomain.domain.com`
   - Example: `community@lists.example.com`
   - Example: `announcements@lists.example.com`

3. **Why use a subdomain?** This approach means you only need to configure DNS for `lists.example.com` instead of your
   main domain, keeping your primary email separate from mailing lists.

3. **Email Server Configuration**: To enable full email functionality, you'll need to configure your mail server or
   email service:
   - **Option A**: Configure your mail server (Postfix, Exchange, etc.) to forward emails to your Rails app
   - **Option B**: Use a service like Mailgun, SendGrid, or Amazon SES with webhook integration
   - **Option C**: Set up ActionMailbox with your preferred email service

### Email Functionality

#### **Inbound Email Processing (ActionMailbox)**

- Emails sent to `community@lists.example.com` are automatically forwarded to all list members
- Original sender information is preserved in forwarded emails
- Replies sent to the list address are distributed to all members
- Only active mailing lists will process emails

#### **Web-Based Broadcasting**

- Send emails to all list members through the web interface
- Compose and send announcements directly from the mailing list page
- All emails include proper list headers and reply-to addresses

### Usage

1. **Creating Lists**:
   - Navigate to "Mailing Lists" in the main navigation
   - Click "New Mailing List"
   - Enter a name (lowercase letters, numbers, hyphens, and underscores only)
   - Add a description
   - Set the active status

2. **Managing Members**:
   - View any mailing list to see current members
   - Add or remove users from the list
   - Members are managed through the web interface

3. **Sending Emails**:
   - **Via Email**: Send an email to `listname@lists.example.com` and it will be forwarded to all members
   - **Via Web**: Click "Send Email" on any mailing list page to compose and send to all members

4. **Editing/Deleting**: Any user can edit or delete existing mailing lists

### List Name Requirements

- Only lowercase letters, numbers, hyphens (`-`), and underscores (`_`) are allowed
- Names must be unique across all mailing lists
- Examples of valid names: `community`, `team-updates`, `dev_announcements`

### DNS Configuration

**You only need to configure DNS for your mailing list subdomain, not your main domain:**

1. **MX Record**: Point `lists.example.com` to your email service
2. **Main Domain**: Keep `example.com` pointing to your regular email server

### Email Service Configuration Examples

#### Mailgun Setup (Recommended)

1. **Create Mailgun Account**: Sign up at [mailgun.com](https://www.mailgun.com/) and verify your account
2. **Add Domain**: Add `lists.example.com` as a domain in your Mailgun dashboard
3. **Install Dependencies**: The `mailgun-ruby` gem is already included in the Gemfile
4. **Environment Variables**: Add these to your `.env` file:
   ```
   MAILGUN_API_KEY=your_mailgun_api_key
   MAILGUN_DOMAIN=lists.example.com
   MAILGUN_SIGNING_KEY=your_mailgun_signing_key
   ```
5. **Configure DNS**: Set up the DNS records provided by Mailgun for `lists.example.com`
6. **Webhook URL**: In Mailgun dashboard, set webhook URL to:
   `https://yourapp.com/rails/action_mailbox/mailgun/inbound_emails`
7. **Production Configuration**: The Rails app is already configured for Mailgun in production

#### SendGrid Setup

1. Configure Inbound Parse webhook: `https://yourapp.com/rails/action_mailbox/sendgrid/inbound_emails`
2. Set up MX records for `lists.example.com` to point to SendGrid

#### Postfix Setup

1. Configure Postfix to pipe emails for `lists.example.com` to your Rails app
2. Set up transport maps specifically for your mailing list subdomain

### Troubleshooting

If you encounter a "Missing required parameter: client_id" error when trying to log in with Google:

1. Make sure you have created a `.env` file in the root of your project
2. Ensure your `.env` file contains the following lines with your actual credentials:
   ```
   GOOGLE_CLIENT_ID=your_actual_client_id_from_google_cloud_console
   GOOGLE_CLIENT_SECRET=your_actual_client_secret_from_google_cloud_console
   MAILING_LIST_DOMAIN=example.com
   MAILING_LIST_SUBDOMAIN=lists
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
* Full-featured mailing list system with email forwarding and web broadcasting
