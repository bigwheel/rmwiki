require 'httpclient'
require 'nokogiri'
require 'json'
require 'uri'
require 'time'

class Rmwiki
  # ここで使われたユーザーはRedMineの方の操作ログに名前が残るよ
  def initialize(wiki_root, username, password)
    @wiki_root = wiki_root
    @http_client = HTTPClient.new
    login username, password
  end

  class SimpleWikiPage
    attr_reader :title, :parent_title, :version, :created_on, :updated_on

    def initialize(raw_obj)
      @title        = raw_obj['title']
      @parent_title = raw_obj['parent'] && raw_obj['parent']['title']
      # Option型ってないんよね
      @version      = raw_obj['version']
      @created_on   = DateTime::iso8601(raw_obj['created_on'])
      @updated_on   = DateTime::iso8601(raw_obj['updated_on'])
    end
  end

  class ExtendedWikiPage < SimpleWikiPage
    attr_reader :text, :author_id, :author_name, :comments
    def initialize(raw_obj)
      super(raw_obj)
      @text        = raw_obj['text']
      @author_id   = raw_obj['author']['id']
      @author_name = raw_obj['author']['name']
      @comments    = raw_obj['comments']
    end
  end

  def all_pages
    response = @http_client.get(File.join(@wiki_root, 'index.json'))
    check_status_code response
    JSON.parse(response.content)['wiki_pages'].map { |raw_obj|
      SimpleWikiPage.new(raw_obj)
    }
  end

  def page page_title
    response = @http_client.get(File.join(@wiki_root, URI::escape(page_title) + '.json'))

    if response.header.status_code == 200
      ExtendedWikiPage.new(JSON.parse(response.content)['wiki_page'])
    else
      nil
    end
  end

  def exist? page_title
    self.page(page_title) != nil
  end

  # スペースの入ったページ名などダメなページ名があるので
  # 返り値として移動後のページ名を返す
  def rename before_title, after_title
    def get_default_parent_id nokogiri_doc
      elem = nokogiri_doc.css('#wiki_page_parent_id option[selected="selected"]').first
      if elem
        elem.attributes['value'].value.to_i
      else
        ''
      end
    end

    rename_form_url = File.join(@wiki_root, before_title, '/rename')
    doc = Nokogiri::HTML(@http_client.get_content(rename_form_url))
    authenticity_token = get_authenticity_token(doc)

    res = @http_client.post(rename_form_url, {
      'authenticity_token'                 => authenticity_token,
      'wiki_page[title]'                   => after_title,
      'wiki_page[redirect_existing_links]' => 0,
      'wiki_page[parent_id]'               => get_default_parent_id(doc)
    })
    check_status_code res, 302
    File.basename(res.header['Location'].first)
  end

  private
  def login username, password
    def fetch_login_url_from_wiki_root
      url = URI.parse(@wiki_root)
      doc = Nokogiri::HTML(@http_client.get_content(@wiki_root))
      url.path = doc.css('.login').first.attributes['href'].value
      url.to_s
    end

    login_url = fetch_login_url_from_wiki_root
    login_page_doc = Nokogiri::HTML(@http_client.get_content(login_url))
    authenticity_token = get_authenticity_token(login_page_doc)
    # redmineは認証失敗したら200,成功したら302が帰る。ks
    check_status_code(@http_client.post(login_url, {
      authenticity_token: authenticity_token,
      username: username,
      password: password
    }), 302)
  end

  def check_status_code response, status_code = 200
    unless response.header.status_code == status_code
      raise '失敗したっぽい' + response.to_s
    end
  end

  def get_authenticity_token nokogiri_doc
    nokogiri_doc.css('input[name="authenticity_token"]').first.attributes['value'].value
  end
end
