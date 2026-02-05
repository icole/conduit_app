class DocumentsController < ApplicationController
  before_action :set_document, only: %i[ show edit update destroy update_content view_content ]
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

  # Sync documents and folders from Google Drive (admin only)
  def refresh_from_google_drive
    unless current_user.admin?
      redirect_to documents_path, alert: "Only administrators can sync from Google Drive."
      return
    end

    folder_id = current_community.settings&.dig("google_drive_folder_id") || ENV["GOOGLE_DRIVE_FOLDER_ID"]

    unless folder_id.present?
      redirect_to documents_path, alert: "Google Drive folder not configured."
      return
    end

    begin
      result = GoogleDriveSyncService.new(current_community, folder_id).sync!

      if result[:success]
        redirect_to documents_path, notice: result[:message]
      else
        redirect_to documents_path, alert: result[:message]
      end
    rescue StandardError => e
      Rails.logger.error("Error syncing from Google Drive: #{e.message}")
      redirect_to documents_path, alert: "Error syncing from Google Drive: #{e.message}"
    end
  end

  # GET /documents/1 or /documents/1.json
  def show
    if @document.uploaded? && @document.file.attached?
      redirect_to rails_blob_path(@document.file, disposition: :inline), allow_other_host: true
    elsif @document.native?
      redirect_to edit_document_path(@document)
    elsif @document.google_drive?
      redirect_to view_content_document_path(@document)
    end
  end

  # GET /documents/1/edit
  def edit
    # Google Drive documents can't be edited here - redirect to view
    if @document.google_drive?
      redirect_to view_content_document_path(@document)
    end
  end

  # POST /documents or /documents.json
  def create
    @document = Document.new(
      title: "Untitled Document",
      storage_type: :native,
      document_folder_id: params.dig(:document, :document_folder_id)
    )

    if @document.save
      redirect_to edit_document_path(@document)
    else
      redirect_to documents_path(folder_id: @document.document_folder_id), alert: "Could not create document."
    end
  end

  # POST /documents/upload
  def upload
    unless params[:file].present?
      redirect_to documents_path(folder_id: params[:folder_id]), alert: "Please select a file to upload."
      return
    end

    file = params[:file]
    @document = Document.new(
      title: file.original_filename,
      storage_type: :uploaded,
      document_folder_id: params[:folder_id]
    )
    @document.file.attach(file)

    if @document.save
      redirect_to documents_path(folder_id: @document.document_folder_id), notice: "File uploaded successfully."
    else
      redirect_to documents_path(folder_id: params[:folder_id]), alert: "Could not upload file."
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
    if @document.google_drive?
      respond_to do |format|
        format.html { redirect_to documents_path, alert: "Cannot delete documents synced from Google Drive." }
        format.json { render json: { error: "Cannot delete synced documents" }, status: :forbidden }
      end
      return
    end

    @document.file.purge if @document.uploaded? && @document.file.attached?
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

  # GET /documents/1/view_content
  # View Google Drive document content using service account
  # Allows users without personal Google Drive access to view documents
  def view_content
    unless @document.google_drive?
      redirect_to edit_document_path(@document)
      return
    end

    file_id = @document.google_drive_file_id
    unless file_id
      flash.now[:alert] = "Could not extract file ID from Google Drive URL"
      render :show
      return
    end

    begin
      api = GoogleDriveApiService.from_service_account
      result = api.export_as_html(file_id)

      if result[:status] == :success
        @document_html_content = result[:content]
        @document_name = result[:name]
      else
        flash.now[:alert] = "Could not load document: #{result[:error]}"
      end
    rescue StandardError => e
      Rails.logger.error("Error fetching Google Drive document content: #{e.message}")
      flash.now[:alert] = "Error loading document content"
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
