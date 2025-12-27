class DecisionsController < ApplicationController
  before_action :set_decision, only: [ :show, :edit, :update, :destroy ]

  def index
    @decisions = Decision.includes(:calendar_event, :document).recent
  end

  def show
  end

  def new
    @decision = Decision.new

    # Pre-populate from params if provided
    if params[:calendar_event_id]
      @decision.calendar_event_id = params[:calendar_event_id]
      event = CalendarEvent.find_by(id: params[:calendar_event_id])
      @decision.decision_date = event&.start_time&.to_date
    end

    if params[:document_id]
      @decision.document_id = params[:document_id]
    end

    @calendar_events = CalendarEvent.order(start_time: :desc).limit(50)
    @documents = Document.order(created_at: :desc).limit(50)
  end

  def edit
    @calendar_events = CalendarEvent.order(start_time: :desc).limit(50)
    @documents = Document.order(created_at: :desc).limit(50)
  end

  def create
    @decision = Decision.new(decision_params)

    if @decision.save
      redirect_to @decision, notice: "Decision was successfully created."
    else
      @calendar_events = CalendarEvent.order(start_time: :desc).limit(50)
      @documents = Document.order(created_at: :desc).limit(50)
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @decision.update(decision_params)
      redirect_to @decision, notice: "Decision was successfully updated."
    else
      @calendar_events = CalendarEvent.order(start_time: :desc).limit(50)
      @documents = Document.order(created_at: :desc).limit(50)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @decision.discard
    redirect_to decisions_path, notice: "Decision was successfully deleted."
  end

  private

  def set_decision
    @decision = Decision.find(params[:id])
  end

  def decision_params
    params.require(:decision).permit(:title, :description, :decision_date, :calendar_event_id, :document_id)
  end
end
