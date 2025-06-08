class DocumentsController < ApplicationController
  before_action :set_document, only: %i[ show edit update destroy ]
  before_action :authenticate_user!

  # GET /documents or /documents.json
  def index
    # Fetch documents from the database
    @documents = Document.all

    # Fetch documents from Google Drive
    fetch_google_drive_documents
  end

  # Handle OAuth2 callback
  def oauth_callback
    # Store the authorization code
    session[:google_auth_code] = params[:code]

    # Redirect to documents index
    redirect_to documents_path, notice: "Google Drive authorization successful!"
  end

  # Refresh documents from Google Drive
  def refresh_from_google_drive
    # Fetch documents from Google Drive
    fetch_google_drive_documents

    # If we got here, the fetch was successful (no redirect)
    redirect_to documents_path, notice: "Documents refreshed from Google Drive!"
  end

  # Fetch documents from Google Drive and store them in the database
  def fetch_google_drive_documents
    begin
      # Get the Google Drive service, passing the authorization code if available
      service = GoogleDriveConfig.drive_service(session[:google_auth_code])

      # If service is nil, authorization is needed
      if service.nil?
        # Get the authorization URL from the thread
        auth_url = Thread.current[:google_auth_url]

        # Clear the session authorization code
        session.delete(:google_auth_code)

        # Redirect to the authorization URL
        redirect_to auth_url, allow_other_host: true
        return
      end

      # Define the query to find Google Docs, Sheets, and Slides
      query = "mimeType='application/vnd.google-apps.document' or mimeType='application/vnd.google-apps.spreadsheet' or mimeType='application/vnd.google-apps.presentation'"

      # Execute the query
      response = service.list_files(q: query, fields: "files(id, name, description, mimeType, webViewLink)")

      # Process each file
      response.files.each do |file|
        # Skip if the document already exists in the database
        next if Document.exists?(google_drive_url: file.web_view_link)

        # Determine document type based on MIME type
        document_type = case file.mime_type
                        when "application/vnd.google-apps.document"
                          "Google Doc"
                        when "application/vnd.google-apps.spreadsheet"
                          "Google Sheet"
                        when "application/vnd.google-apps.presentation"
                          "Google Slides"
                        else
                          "Other"
                        end

        # Create a new document record
        Document.create!(
          title: file.name,
          description: file.description || "Google #{document_type}",
          google_drive_url: file.web_view_link,
          document_type: document_type
        )
      end

      # Clear the session authorization code after successful use
      session.delete(:google_auth_code)
    rescue => e
      # Log the error and continue
      Rails.logger.error("Error fetching Google Drive documents: #{e.message}")
    end
  end

  # GET /documents/1 or /documents/1.json
  def show
  end

  # GET /documents/new
  def new
    @document = Document.new
  end

  # GET /documents/1/edit
  def edit
  end

  # POST /documents or /documents.json
  def create
    @document = Document.new(document_params)

    respond_to do |format|
      if @document.save
        format.html { redirect_to @document, notice: "Document was successfully created." }
        format.json { render :show, status: :created, location: @document }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @document.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /documents/1 or /documents/1.json
  def update
    respond_to do |format|
      if @document.update(document_params)
        format.html { redirect_to @document, notice: "Document was successfully updated." }
        format.json { render :show, status: :ok, location: @document }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @document.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /documents/1 or /documents/1.json
  def destroy
    @document.destroy!

    respond_to do |format|
      format.html { redirect_to documents_path, status: :see_other, notice: "Document was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_document
      @document = Document.find(params.require(:id))
    end

    # Only allow a list of trusted parameters through.
    def document_params
      params.require(:document).permit(:title, :description, :google_drive_url, :document_type)
    end
end
