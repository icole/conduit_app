class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @posts = Post.order(created_at: :desc)
    @post = Post.new
    @tasks = current_user.tasks
    @task = Task.new
  end
end
