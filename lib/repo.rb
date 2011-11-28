class Repo
  
  attr_accessor :user, :name, :git
  
  def self.find(user, name)
    if File.exists? repo_path(user, name)
      Repo.new user, name
    else
      nil
    end
  end
  
  def self.clone(user, name, clone_url)
    Resque.enqueue(Cloner, user, name, clone_url)
  end
  
  def self.clone_now(user, name, clone_url)
    tmp_repo_path = repo_path(user, name)
    FileUtils.mkdir_p tmp_repo_path
    `cd #{tmp_repo_path} && git clone #{clone_url} ./`
    repo = Repo.new(user, name)
    repo.pull
    repo.reindex
  end
  
  def initialize(user, name)
    @user = user
    @name = name
    @git = Grit::Repo.new(repo_path)
  end
  
  def pull
    `cd #{repo_path} && git reset --hard && git pull`
    Dir["#{repo_path}/*"].each do |file_path|
      puts "-- #{file_path}"
      `rm -rf #{file_path}` unless file_path =~ /\/(templates||posts)$/
    end
    Dir["#{repo_path}/*/*"].each do |file_path|
      puts "-- #{file_path}"
      `rm -rf #{file_path}` unless file_path =~ /(\.liquid$)|(\.yml$)/
    end
  end
  
  def post(slug)
    post_data = LOCAL_REPO_PATH ? load_post_file(slug) : ElasticSearch.get_post(user, name, slug)
    post_data ? Post.new(post_data) : nil
  end
  
  def index_post(slug, path=nil)
    post_data = load_post_file(slug, path)
    ElasticSearch.index_post user, name, slug, post_data
  end
  
  def repo_path
    Repo.repo_path(user, name)
  end
  
  def reindex
    Resque.enqueue(Indexer, user, name)
  end
  
  def reindex_now
    ElasticSearch.clear(user, name)
    Dir["#{repo_path}/posts/*.yml"].each do |path|
      slug = File.basename(path, ".yml")
      index_post slug, path
    end
    ElasticSearch.save_repo_metadata(user, name, :commit => commit_hash)
  end
  
  def render_index(context={}, options={})
    render_collection('*', context, options)
  end
  
  def render_collection(query, context={}, options={})
    html = ""
    query_options = { :sort => [{ :created_at_sortable => :desc }] }
    page = (options[:page] || 1).to_i
    size = (options[:page_size] || 10).to_i
    query_options[:from] = (page-1) * size
    query_options[:size] = size
    results = ElasticSearch.search(user, name, query, query_options)
    context[:posts] = results.hits.collect do |post|
      format_post(post, context)
    end
    context[:no_results] = true if results.hits.empty?
    page_url_prefix = "?"
    if options[:search]
      page_url_prefix += "q=#{query}&" 
      context[:query] = query
    end
    if page > 1
      context[:previous_page] = "#{page_url_prefix}page=#{page-1}"
    end
    if results.total > results.hits.size + (size * (page-1))
      context[:next_page] = "#{page_url_prefix}page=#{page+1}"
    end
    render_layout(context, options)
  end

  def render_post(post, context={})
    context[:posts] = [format_post(post, context)]
    render_layout(context)
  end
  
  def commit_hash
    git.commits('master',1).first
  end
  
  def cached_commit_hash
    result = ElasticSearch.repo_metadata(user, name)
    result ? result['commit'] : nil
  end
  
  protected
  def format_post(post, context)
    post.content = RDiscount.new(post.content).to_html
    post.url = "#{context[:url_prefix]}/#{post.id}"
    post.to_hash
  end
  
  def load_post_file(slug, post=nil)
    path ||= File.join(repo_path, 'posts', slug) + ".yml"
    return nil unless File.exist?(path)
    post_data = YAML.load_file(path)
    add_git_data(post_data, path)
    post_data['content'] = File.read(path).sub /---.*---\n/m, ''
    post_data
  end
  
  def add_git_data(post_data, path)
    # loop through commits until we find an edit
    path = path.sub repo_path+'/', ''
    last_commit_for_path = nil
    first_commit_for_path = nil
    git.commits('master', false).each do |commit|
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
      post_data['created_at_sortable'] = first_commit_for_path.authored_date.to_i
      post_data['modified_at'] = last_commit_for_path.authored_date
      post_data['modified_at_sortable'] = last_commit_for_path.authored_date.to_i
    else
      puts "no last commit for #{path}"
    end
  end
  
  def render_layout(content, options={})
    template_file = options[:template] || 'index.html.liquid'
    layout = Liquid::Template.parse(File.read File.join(repo_path, 'templates', template_file))
    layout.render Hashie::Mash.new content
  end
  
  def self.repo_path(user=@user, name=@name)
    if LOCAL_REPO_PATH
      LOCAL_REPO_PATH.sub('<user>', user).sub('<repo>', name)
    else
      base_path = REPO_CACHE_PATH
      "#{base_path}/#{user}/#{name}"
    end
  end
  
end