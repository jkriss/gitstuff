class Repo
  
  attr_accessor :user, :name
  
  def self.find(user, name)
    if File.exists? repo_path(user, name)
      Repo.new user, name
    else
      nil
    end
  end
  
  def initialize(user, name)
    @user = user
    @name = name
  end
  
  def post(slug)
    post_data = ElasticSearch.get_post(user, name, slug)
    post_data ? Post.new(post_data) : nil
  end
  
  def index_post(slug, path=nil)
    path ||= File.join(repo_path, 'posts', slug) + ".yml"
    puts "indexing #{path}..."
    post_data = YAML.load_file(path)
    post_data['content'] = File.read(path).sub /---.*---\n/m, ''  
    ElasticSearch.index_post user, name, slug, post_data
  end
  
  def repo_path
    Repo.repo_path(user, name)
  end
  
  def reindex
    ElasticSearch.clear(user, name)
    Dir["#{repo_path}/posts/*.yml"].each do |path|
      slug = File.basename(path, ".yml")
      index_post slug, path
    end
  end

  def render_post(post)
    post.content = RDiscount.new(post.content).to_html
  
    template = Liquid::Template.parse(File.read File.join(repo_path, 'layouts', 'post.html.liquid'))
    rendered_post = template.render(post.to_hash)
  
    layout = Liquid::Template.parse(File.read File.join(repo_path, 'layouts', 'page.html.liquid'))
    layout.render 'content' => rendered_post
  end
  
  protected
  def self.repo_path(user=@user, name=@name)
    "../#{name}"
  end
  
end