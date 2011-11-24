require 'rubygems'
require 'bundler'
Bundler.setup
Bundler.require
require 'lib/elastic_search'

def get_repo_path(user, repo)
  "../#{repo}/"
end

def render_post(user, repo, post_name)
  repo_path = get_repo_path(user, repo)
  path = File.join(repo_path, 'posts', params[:post]) + ".yml"
  post_data = YAML.load_file(path)
  
  
  post_data['content'] = File.read(path).sub /---.*---\n/m, ''
  
  # for now, update the index on every render
  ElasticSearch.index_post user, repo, post_name, post_data
  
  post_data['content'] = RDiscount.new(post_data['content']).to_html
  
  template = Liquid::Template.parse(File.read File.join(repo_path, 'layouts', 'post.html.liquid'))
  post_content = template.render(post_data)
  
  layout = Liquid::Template.parse(File.read File.join(repo_path, 'layouts', 'page.html.liquid'))
  layout.render 'content' => post_content
end

get '/' do
  "yo."
end

get '/:user/:repo/search' do
  results = ElasticSearch.search params[:user], params[:repo], params[:q]
  results.inspect.to_s
end

get '/:user/:repo/:post' do
  render_post params[:user], params[:repo], params[:post]
end