require 'spec_helper'

describe Rmwiki do
  # sample site
  wiki_root = 'https://www.hostedredmine.com/projects/redminefs-test-project/wiki/'
  username = 'bigwheel'
  password = '4CrY39Ellb07'
  it '正しいアカウントならインスタンスが作れる' do
    expect { Rmwiki.new(wiki_root, username, password) }.not_to raise_error
  end

  it '正しくないアカウントでは例外が出る' do
    expect { Rmwiki.new(wiki_root, username, 'invalid_pass') }.to raise_error
  end

  describe '細かい挙動' do
    before(:context) do
      @subject = Rmwiki.new(wiki_root, username, password)
    end

    it 'とりあえずall_pagesが呼べる' do
      expect { @subject.all_pages }.not_to raise_error
    end

    it 'とりあえずページ詳細が取れる' do
      page = @subject.page('C')

      expect(page.title).to eq('C')
      expect(page.parent_title).to eq('Parent')
      expect(page.text).not_to be_empty
      expect(page.author_name).to eq('bigwheel k')
      expect(page.author_id).to eq(33563)
      expect(page.created_on).to eq(DateTime.parse('2014-09-24T18:13:16Z'))
    end

    it 'とりあえずrenameが呼べる' do
      expect { @subject.rename }.not_to raise_error
    end

    it 'renameの細かいテスト' do
      'まずページBが存在しない
      Aは存在する

      AをBへリネーム

      Aが存在せず
      Bは存在する

      最後に元へ戻す動作'
    end
  end
end
