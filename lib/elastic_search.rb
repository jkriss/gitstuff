class ElasticSearch
  include HTTParty
  base_uri 'http://localhost:9200'
  format :json
  
  def self.index_post(user, repo, slug, post_data)
    self.put "/#{user}/#{repo}/#{slug}", :body => post_data.to_json
  end
  
  def self.get_post(user, repo, slug)
    result = self.get "/#{user}/#{repo}/#{slug}"
    post = result['_source']
    post['id'] = result['_id']
    post
  end
  
  def self.search(user, repo, query)
    results = self.get "/#{user}/#{repo}/_search?q=#{query}"
    if !results['hits'] || results['hits']['total'] == 0
      []
    else
      results['hits']['hits'].collect do |result|
        p = Post.new(result['_source'])
        p.id = result['_id']
        p
      end
    end
  end
  
  def self.clear(user, repo)
    self.delete "/#{user}/#{repo}"
  end
end