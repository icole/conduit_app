class DocumentFoldersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_document_folder, only: %i[update destroy]

  def create
    @document_folder = DocumentFolder.new(document_folder_params)
    @document_folder.created_by = current_user

    if @document_folder.save
      redirect_to documents_path(folder_id: @document_folder.parent_id), notice: "Folder created."
    else
      redirect_to documents_path(folder_id: @document_folder.parent_id), status: :unprocessable_entity, alert: @document_folder.errors.full_messages.join(", ")
    end
  end

  def update
    if @document_folder.update(document_folder_params)
      redirect_to documents_path(folder_id: @document_folder.parent_id), notice: "Folder renamed."
    else
      redirect_to documents_path(folder_id: @document_folder.parent_id), status: :unprocessable_entity, alert: @document_folder.errors.full_messages.join(", ")
    end
  end

  def destroy
    if @document_folder.synced_from_drive?
      redirect_to documents_path(folder_id: @document_folder.parent_id), alert: "Cannot delete folders synced from Google Drive."
      return
    end

    parent_id = @document_folder.parent_id
    @document_folder.destroy

    redirect_to documents_path(folder_id: parent_id), notice: "Folder deleted."
  end

  private

  def set_document_folder
    @document_folder = DocumentFolder.find(params[:id])
  end

  def document_folder_params
    params.require(:document_folder).permit(:name, :parent_id)
  end
end
