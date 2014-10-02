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

    it 'ページの存在を確認できる' do
      expect(@subject.exist?('C')).to be_truthy
    end

    it 'ページの不在を確認できる' do
      expect(@subject.exist?('not_exists')).to be_falsey
    end

    it '存在しないページの詳細を取ろうとするとnilが帰る' do
      expect(@subject.page('not_exists')).to be_nil
    end

    it '親がないページのrenameテスト' do
      expect(@subject.exist?('A')).to be_truthy
      expect(@subject.exist?('B')).to be_falsey

      @subject.rename 'A', 'B'

      expect(@subject.exist?('A')).to be_falsey
      expect(@subject.exist?('B')).to be_truthy

      @subject.rename 'B', 'A' # 面倒なので元に戻しておく
    end

    it '親があるページのrenameテスト' do
      expect(@subject.exist?('Child')).to be_truthy
      expect(@subject.exist?('NextChild')).to be_falsey

      @subject.rename 'Child', 'NextChild'

      expect(@subject.exist?('Child')).to be_falsey
      expect(@subject.exist?('NextChild')).to be_truthy

      @subject.rename 'NextChild', 'Child' # 面倒なので元に戻しておく
    end

    it 'スペースを含む名前へ変更しようとしてもアンダースコアで置換される' do
      renamed_name = @subject.rename 'A', 'Space Ga Aru'
      @subject.rename renamed_name, 'A' # 元に戻しておく
      expect(renamed_name).to eq('Space_Ga_Aru')
    end

    it '親のあるページを別の親へ移動できる' do
      @subject.rename 'Child', 'Child', 'Wiki'

      page = @subject.page('Child')
      expect(page.parent_title).to eq('Wiki')

      @subject.rename 'Child', 'Child', 'Parent' # 元に戻しておく
    end

    it '親のないページを別の親へ移動できる' do
      @subject.rename 'Parentless', 'Parentless', 'Wiki'

      page = @subject.page('Parentless')
      expect(page.parent_title).to eq('Wiki')
    end

    # 上のテストの副作用はこっちで戻す
    it '親のあるページを親なしへ移動できる' do
      @subject.rename 'Parentless', 'Parentless', nil

      page = @subject.page('Parentless')
      expect(page.parent_title).to be_nil
    end

    it '存在しない親ページを指定すると例外が出る' do
      expect {
        @subject.rename('Parentless', 'Parentless', 'not_exist_page')
      }.to raise_error
    end
  end
end
