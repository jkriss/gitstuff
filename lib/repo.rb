require 'digest/md5'

class Repo
  
  attr_accessor :user, :name, :git
  
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
    @git = Grit::Repo.new(repo_path)
  end
  
  def post(slug)
    post_data = ElasticSearch.get_post(user, name, slug)
    post_data ? Post.new(post_data) : nil
  end
  
  def index_post(slug, path=nil)
    path ||= File.join(repo_path, 'posts', slug) + ".yml"
    puts "indexing #{path}..."
    post_data = YAML.load_file(path)
    add_git_data(post_data, path)
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
  
  def render_index(context={})
    html = ""
    ElasticSearch.search(user, name, '*').each do |post|
      html += render_raw_post(post, context.merge({ :url => "#{context[:url_prefix]}/#{post.id}" }))
    end
    render_layout(html, context)
  end

  def render_post(post, context={})
    rendered_post = render_raw_post(post, context)
    render_layout(rendered_post, context)
  end
  
  protected
  def add_git_data(post_data, path)
    # loop through commits until we find an edit
    path = path.sub repo_path+'/', ''
    last_commit_for_path = nil
    first_commit_for_path = nil
    git.commits.each do |commit|
      commit.diffs.each do |diff|
        if diff.b_path == path
          last_commit_for_path ||= commit
          first_commit_for_path = commit
        end
      end
    end
    if last_commit_for_path
      author = last_commit_for_path.author
      post_data['author'] = { :name => author.name, :email => author.email }
      post_data['gravatar'] = "http://www.gravatar.com/avatar/#{Digest::MD5.hexdigest(author.email)}"
      post_data['created_at'] = first_commit_for_path.authored_date
      post_data['modified_at'] = last_commit_for_path.authored_date
    end
  end
  
  def render_raw_post(post, context={})
    post.content = RDiscount.new(post.content).to_html  
    template = Liquid::Template.parse(File.read File.join(repo_path, 'layouts', 'post.html.liquid'))
    template.render Hashie::Mash.new(context.merge(post.to_hash))
  end
  
  def render_layout(content, context={})
    layout = Liquid::Template.parse(File.read File.join(repo_path, 'layouts', 'page.html.liquid'))
    layout.render Hashie::Mash.new context.merge(:content => content)
  end
  
  def self.repo_path(user=@user, name=@name)
    "../#{name}"
  end
  
end