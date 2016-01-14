class Site::PostsController < Site::BaseController
  before_action :set_post, only: :show
  after_action :increment_views, only: :show

  def index
    @posts = if params[:tag]
      Post.published.joins(:tags).where('tags.title LIKE ?', params[:tag])
    else
      Post.published
    end.page(params[:page])
  end

  def show; end

  private

  def set_post
    @post = Post.find_by(permalink: params[:id])
  end

  def increment_views
    if @post
      key = "post_#{@post.id}_incrementd_at".to_sym
      if session[key].nil? || session[key] < 5.minutes.ago
        @post.increment_views
        session[key] = Time.zone.now
      end
    end
  end

end
