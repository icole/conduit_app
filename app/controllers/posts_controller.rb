class PostsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_post, only: [ :update, :destroy ]

  def index
    @posts = Post.order(created_at: :desc)
    @post = Post.new
  end

  def create
    @post = current_user.posts.new(post_params)

    respond_to do |format|
      if @post.save
        format.turbo_stream
        format.html { redirect_to dashboard_index_path, notice: "Post was successfully created." }
      else
        format.turbo_stream { render turbo_stream: turbo_stream.replace("new-post-form", partial: "posts/form", locals: { post: @post }) }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @post.update(post_params)
        format.turbo_stream
        format.html { redirect_to dashboard_index_path, notice: "Post was successfully updated." }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @post.destroy

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to dashboard_index_path, notice: "Post was successfully deleted." }
    end
  end

  private

  def set_post
    @post = current_user.posts.find(params[:id])
  end

  def post_params
    params.require(:post).permit(:content)
  end
end
