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

  def tree
    def sub_page_tree all_pages, page_title
      def all_pages.select_child_pages parent_title
        self.select { |page| page.parent_title == parent_title }
      end
      pages = all_pages.select_child_pages(page_title).map { |page|
        page.instance_variable_set(:@children, sub_page_tree(all_pages, page.title))
        def page.children
          @children
        end
        page
      }
      Hash[pages.map { |page| [page.title, page] }]
    end

    sub_page_tree(self.all_pages, nil)
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
  def rename before_title, after_title, parent_title = :default
    def get_page_title_id_map nokogiri_doc
      page_id_and_anme = nokogiri_doc.css('#wiki_page_parent_id option').
        map { |i| i.text =~ /(?:.*» )?(.+)/; [$1, i.attributes['value'].value.to_i] }.
        select { |page_title, id| page_title }
      Hash[page_id_and_anme]
    end

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
    parent_id = if parent_title == :default
                  get_default_parent_id(doc)
                elsif parent_title == nil
                  ''
                else
                  page_title_to_id = get_page_title_id_map(doc)
                  unless page_title_to_id.has_key? parent_title
                    raise '指定された親ページが存在しません'
                  end
                  page_title_to_id[parent_title]
                end

    res = @http_client.post(rename_form_url, {
      'authenticity_token'                 => authenticity_token,
      'wiki_page[title]'                   => after_title,
      'wiki_page[redirect_existing_links]' => 0,
      'wiki_page[parent_id]'               => parent_id
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
