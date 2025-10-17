class CalendarEvents::DocumentLinksController < ApplicationController
  before_action :set_calendar_event

  def create
    document = Document.find(params[:document_id])

    if @calendar_event.documents << document
      redirect_to calendar_event_path(@calendar_event), notice: "Document linked successfully."
    else
      redirect_to calendar_event_path(@calendar_event), alert: "Failed to link document."
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    redirect_to calendar_event_path(@calendar_event), alert: "Document is already linked."
  end

  def destroy
    document = Document.find(params[:id])
    @calendar_event.documents.delete(document)
    redirect_to calendar_event_path(@calendar_event), notice: "Document unlinked successfully."
  end

  private

  def set_calendar_event
    @calendar_event = CalendarEvent.find(params[:calendar_event_id])
  end
end
