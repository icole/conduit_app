class ChoresController < ApplicationController
  before_action :authenticate_user!
  before_action :set_chore, only: [ :show, :edit, :update, :destroy, :complete, :volunteer, :approve ]

  def index
    @current_view = params[:view] || "my_responsibilities"

    case @current_view
    when "my_responsibilities"
      @my_chores = current_user.assigned_chores.active.includes(:chore_assignments, :proposed_by)
      @other_chores = Chore.active.includes(chore_assignments: :user, proposed_by: {}).where.not(id: @my_chores.pluck(:id))
    when "all_chores"
      @all_chores = Chore.active.includes(chore_assignments: :user, proposed_by: {})
    when "proposed"
      @proposed_chores = Chore.proposed.includes(:proposed_by, :likes)
    else
      @my_chores = current_user.assigned_chores.active.includes(:chore_assignments, :proposed_by)
      @other_chores = Chore.active.includes(chore_assignments: :user, proposed_by: {}).where.not(id: @my_chores.pluck(:id))
    end

    # Get chores that need help
    @chores_needing_help = Chore.active.includes(:chore_assignments).select(&:needs_volunteer?)
  end

  def show
    @chore_completions = @chore.chore_completions.recent.includes(:completed_by).limit(10)
    @current_assignment = @chore.chore_assignments.active.includes(:user).first
    @comments = @chore.comments.includes(:user, :likes).order(created_at: :asc)
    @comment = Comment.new
  end

  def new
    @chore = Chore.new
  end

  def create
    @chore = Chore.new(chore_params)

    if @chore.save
      redirect_to chores_path(view: "proposed"), notice: "Chore proposed successfully!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @chore.update(chore_params)
      if @chore.proposed?
        redirect_to chores_path(view: "proposed"), notice: "Chore updated successfully!"
      else
        redirect_to @chore, notice: "Chore updated successfully!"
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    was_proposed = @chore.proposed?
    @chore.discard
    if was_proposed
      redirect_to chores_path(view: "proposed"), notice: "Chore removed successfully!"
    else
      redirect_to chores_path, notice: "Chore removed successfully!"
    end
  end

  def complete
    @chore.mark_complete!(current_user, notes: params[:notes])
    redirect_to chores_path, notice: "Chore marked as complete!"
  rescue => e
    redirect_to chores_path, alert: "Error marking chore as complete: #{e.message}"
  end

  def volunteer
    assignment = @chore.chore_assignments.build(user: current_user, start_date: Date.current)

    if assignment.save
      redirect_to chores_path, notice: "Thank you for volunteering!"
    else
      redirect_to chores_path, alert: "Error volunteering for chore."
    end
  end

  def approve
    if current_user.admin? || @chore.proposed_by == current_user
      begin
        @chore.approve!
        redirect_to chores_path(view: "proposed"), notice: "Chore approved and activated!"
      rescue => e
        if e.message.include?("frequency")
          redirect_to chores_path(view: "proposed"), alert: "Cannot approve chore: frequency must be set first. Please edit the chore to add a frequency."
        else
          redirect_to chores_path(view: "proposed"), alert: "Error approving chore: #{e.message}"
        end
      end
    else
      redirect_to chores_path(view: "proposed"), alert: "You don't have permission to approve this chore."
    end
  end

  def bulk_import
    # Show the bulk import form
  end

  def bulk_create
    chores_text = params[:chores_text]
    default_frequency = params[:default_frequency]
    proposed_by_id = params[:proposed_by_id]

    if chores_text.blank?
      redirect_to bulk_import_chores_path, alert: "Please enter some chores to import."
      return
    end

    imported_chores = []
    failed_chores = []

    # Parse the text - each line is a chore
    chores_text.strip.split("\n").each do |line|
      line = line.strip
      next if line.blank?

      # Remove common list prefixes (bullets, numbers, dashes)
      line = line.gsub(/^\s*[-*•]\s*/, "") # Remove bullet points
      line = line.gsub(/^\s*\d+\.\s*/, "") # Remove numbered lists
      line = line.strip

      next if line.blank?

      # Parse name and description if separated by colon, dash, or pipe
      name, description = nil, nil

      if line.include?(" - ")
        name, description = line.split(" - ", 2)
      elsif line.include?(": ")
        name, description = line.split(": ", 2)
      elsif line.include?(" | ")
        name, description = line.split(" | ", 2)
      else
        name = line
        description = nil
      end

      name = name&.strip
      description = description&.strip

      next if name.blank?

      chore_params = {
        name: name,
        description: description,
        proposed_by_id: proposed_by_id
      }
      chore_params[:frequency] = default_frequency if default_frequency.present?

      chore = Chore.new(chore_params)

      if chore.save
        imported_chores << chore
      else
        failed_chores << { name: name, errors: chore.errors.full_messages }
      end
    end

    if imported_chores.any?
      message = "Successfully imported #{imported_chores.count} chores"
      if failed_chores.any?
        message += " #{failed_chores.count} chores failed to import."
      end
      redirect_to chores_path(view: "proposed"), notice: message
    else
      error_details = failed_chores.any? ? " Errors: #{failed_chores.map { |f| "#{f[:name]} (#{f[:errors].join(', ')})" }.join('; ')}" : ""
      redirect_to bulk_import_chores_path, alert: "No chores could be imported. Please check your input.#{error_details}"
    end
  end

  private

  def set_chore
    @chore = Chore.find(params[:id])
  end

  def chore_params
    params.require(:chore).permit(:name, :description, :frequency, :frequency_details, :proposed_by_id)
  end
end
