require 'rubygems'
require 'bundler'
Bundler.setup
Bundler.require

def get_repo_path(user, repo)
  "../#{repo}/"
end

def render_post(repo_path, post_name)
  path = File.join(repo_path, 'posts', params[:post]) + ".yml"
  post_data = YAML.load_file(path)
  post_data['content'] = File.read(path).sub /---.*---\n/m, ''
  post_data['content'] = RDiscount.new(post_data['content']).to_html
  
  template = Liquid::Template.parse(File.read File.join(repo_path, 'layouts', 'post.html.liquid'))
  post_content = template.render(post_data)
  
  layout = Liquid::Template.parse(File.read File.join(repo_path, 'layouts', 'page.html.liquid'))
  layout.render 'content' => post_content
end

get '/' do
  "yo."
end

get '/:user/:repo/:post' do
  repo_path = get_repo_path(params[:user], params[:repo])
  render_post repo_path, params[:post]
end