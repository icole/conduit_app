class DocumentsController < ApplicationController
  before_action :set_document, only: %i[ show edit update destroy update_content ]
  before_action :authenticate_user!
  skip_before_action :verify_authenticity_token, only: [ :update_content ]

  # GET /documents or /documents.json
  def index
    # Current folder (nil means root)
    @current_folder = params[:folder_id].present? ? DocumentFolder.find(params[:folder_id]) : nil

    # Subfolders in current folder
    @folders = DocumentFolder.where(parent_id: @current_folder&.id).order(:name)

    # Sortable columns
    sort_column = params[:sort] || "updated_at"
    sort_direction = params[:direction] || "desc"

    # Validate sort column to prevent SQL injection
    allowed_columns = %w[title document_type created_at updated_at]
    sort_column = "updated_at" unless allowed_columns.include?(sort_column)

    # Validate sort direction
    sort_direction = "desc" unless %w[asc desc].include?(sort_direction)

    # Documents in current folder
    @documents = Document.where(document_folder_id: @current_folder&.id).order("#{sort_column} #{sort_direction}")
  end

  # Refresh documents from Google Drive
  def refresh_from_google_drive
    folder_id = ENV["GOOGLE_DRIVE_FOLDER_ID"]

    unless folder_id.present?
      redirect_to documents_path, alert: "Google Drive folder not configured. Set GOOGLE_DRIVE_FOLDER_ID environment variable."
      return
    end

    begin
      # Use the service account to access Google Drive (same as Community Documents)
      service = GoogleDriveApiService.from_service_account
      result = service.list_recent_files(folder_id, max_results: 100)

      if result[:status] == :success
        documents_created = 0
        result[:files].each do |file|
          # Skip if not a Google Doc/Sheet/Slides
          next unless file[:mime_type]&.start_with?("application/vnd.google-apps.")

          # Skip if already exists
          next if Document.exists?(google_drive_url: file[:web_link])

          # Determine document type
          document_type = case file[:mime_type]
          when "application/vnd.google-apps.document"
            "Google Doc"
          when "application/vnd.google-apps.spreadsheet"
            "Google Sheet"
          when "application/vnd.google-apps.presentation"
            "Google Slides"
          else
            next # Skip other types
          end

          # Create document record
          Document.create!(
            title: file[:name],
            description: "Imported from Community Documents",
            google_drive_url: file[:web_link],
            document_type: document_type
          )
          documents_created += 1
        end

        if documents_created > 0
          redirect_to documents_path, notice: "Successfully imported #{documents_created} document(s) from Google Drive!"
        else
          redirect_to documents_path, notice: "No new documents found to import."
        end
      else
        redirect_to documents_path, alert: "Failed to fetch documents from Google Drive: #{result[:error]}"
      end
    rescue StandardError => e
      Rails.logger.error("Error importing documents from Google Drive: #{e.message}")
      redirect_to documents_path, alert: "Error importing documents: #{e.message}"
    end
  end

  # GET /documents/1 or /documents/1.json
  def show
    # Native documents go straight to edit mode (like Google Docs)
    if @document.native?
      redirect_to edit_document_path(@document)
    end
  end

  # GET /documents/new
  def new
    @document = Document.new
    @document.document_folder_id = params[:folder_id] if params[:folder_id].present?
  end

  # GET /documents/1/edit
  def edit
  end

  # POST /documents or /documents.json
  def create
    @document = Document.new(document_params)

    respond_to do |format|
      if @document.save
        # Native documents go to edit, Google Drive docs go to show
        if @document.native?
          format.html { redirect_to edit_document_path(@document), notice: "Document was successfully created." }
        else
          format.html { redirect_to @document, notice: "Document was successfully created." }
        end
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
    @document.discard

    respond_to do |format|
      format.html { redirect_to documents_path, status: :see_other, notice: "Document was successfully deleted." }
      format.json { head :no_content }
    end
  end

  # PATCH /documents/1/content
  # API endpoint for the React editor to save content
  def update_content
    if @document.update(content: params[:content])
      render json: { status: "ok", updated_at: @document.updated_at }
    else
      render json: { status: "error", errors: @document.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_document
      @document = Document.find(params.require(:id))
    end

    # Only allow a list of trusted parameters through.
    def document_params
      params.require(:document).permit(:title, :description, :google_drive_url, :document_type, :content, :storage_type, :document_folder_id)
    end
end
