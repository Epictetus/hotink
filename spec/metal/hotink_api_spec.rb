require 'spec_helper'

describe HotinkApi do
  include Rack::Test::Methods

  def app
    HotinkApi
  end

  before do
    @account = Factory(:account)
    stubbed_uri = Addressable::URI.parse("http://#{@account.name}.yoursite.net")
    Addressable::URI.stub(:parse).and_return(stubbed_uri)
  end
  
  after do
    Account.delete_all
  end
  
  describe "Articles" do
    describe "GET to /articles/:id.xml" do
      it "should return an XML representation of a published article" do
        @article = Factory(:detailed_article, :account => @account)
        get "/articles/#{@article.to_param}.xml"

        last_response.should be_ok
        last_response.headers['Content-Type'].should == "text/xml"
        last_response.body.should == @article.to_xml
      end
      
      it "should not return an unpublished article" do
         @draft_article = Factory(:draft_article, :account => @account)
         @scheduled_article = Factory(:scheduled_article, :account => @account)

         get "/articles/#{@draft_article.to_param}.xml"
         last_response.should be_not_found

         get "/articles/#{@scheduled_article.to_param}.xml"
         last_response.should be_not_found        
       end
    end
    
    describe "GET to /articles.xml" do
      before do
        @recently_published_articles = (1..2).collect{ |n| Factory(:detailed_article, :published_at => n.hours.ago, :account => @account) }
        @just_published_article = Factory(:detailed_article, :account => @account)
      end

      it "should return an XML array of only published articles" do
        draft = Factory(:draft_article, :account => @account)
        scheduled = Factory(:scheduled_article, :account => @account)
        get "/articles.xml"

        last_response.should be_ok
        last_response.headers['Content-Type'].should == "text/xml"
        last_response.body.should == @account.articles.published.by_date_published(:desc).paginate(:page => 1, :per_page => 20).to_xml
      end

      it "should paginate returned articles" do
        page = 2
        per_page = 5
        @paginated_articles = (1..10).collect{ Factory(:detailed_article, :account => @account) }
        get "/articles.xml?page=#{page}&per_page=#{per_page}"

        last_response.should be_ok
        last_response.headers['Content-Type'].should == "text/xml"
        last_response.body.should == @account.articles.published.by_date_published(:desc).paginate(:page => page, :per_page => per_page).to_xml
      end

      it "should return specific articles instead, if requested" do
        first_article = @recently_published_articles.first
        second_article = @recently_published_articles.second        
        get "/articles.xml", :ids => [first_article.id, second_article.id]

        last_response.should be_ok
        last_response.headers['Content-Type'].should == "text/xml"
        last_response.body.should == @account.articles.published.all(:conditions => { :id => [first_article.id, second_article.id] }).to_xml
      end

      it "should find articles by section id, if requested" do
        category = Factory(:category, :account => @account)
        articles = (1..3).collect{ Factory(:detailed_article, :section => category, :account => @account) }
        get "/articles.xml", :section_id => category.id

        last_response.should be_ok
        last_response.headers['Content-Type'].should == "text/xml"
        last_response.body.should == @account.articles.published.by_published_at(:desc).paginate(:page => 1, :per_page => 20, :conditions => { :section_id => category.id }).to_xml
      end

      it "should find articles by tag" do
        get "/articles.xml", :tagged_with => "flagged"

        last_response.should be_ok
        last_response.headers['Content-Type'].should == "text/xml"
        last_response.body.should == @account.articles.tagged_with('flagged', :on => :tags).published.by_published_at(:desc).paginate(:page => 1, :per_page => 20).to_xml        
      end
    end
  end
  
  describe "Categories" do
    describe "GET to /categories.xml" do
      before do
        @categories = (1..5).collect { Factory(:category, :account => @account) }
        @inactive_category = Factory(:category, :account => @account, :active => false)
        @subcategories = Factory(:category, :account => @account, :parent => @categories.first)
      end

      it "should return a list of active categories" do
        get "/categories.xml"

        last_response.should be_ok
        last_response.headers['Content-Type'].should == "text/xml"
        last_response.body.should == @categories.to_xml
      end        
    end 

    describe "GET to /categories/:id.xml" do
      it "should find category by id" do
        @category = Factory(:category, :account => @account)
        get "/categories/#{@category.id}.xml"

        last_response.should be_ok
        last_response.headers['Content-Type'].should == "text/xml"
        last_response.body.should == @category.to_xml
      end

      it "should find category by name" do
        @category = Factory(:category, :name => "News", :account => @account)
        get "/categories/#{@category.name}.xml"

        last_response.should be_ok
        last_response.headers['Content-Type'].should == "text/xml"
        last_response.body.should == @category.to_xml
      end
    end
  end

  describe "Issues" do
    describe "GET to /issues.xml" do
      before do
        @issues = (1..5).collect { |n| Factory(:issue, :date => n.days.ago,:account => @account) }
        @processing_issue = Factory(:issue_being_processed, :account => @account)
      end

      it "should return an array of published issues" do
        get "/issues.xml"

        last_response.should be_ok
        last_response.headers['Content-Type'].should == "text/xml"

        @account.issues.processed.should_not include(@processing_issue)
        last_response.body.should == @account.issues.processed.paginate(:page => 1, :per_page => 15, :order => "date DESC").to_xml
      end
    end

    describe "GET to /issues/id.xml" do
      it "should return an XML respresentation of the issue" do
        @issue = Factory(:issue, :account => @account)
        get "/issues/#{@issue.id}.xml"

        last_response.should be_ok
        last_response.headers['Content-Type'].should == "text/xml"
        last_response.body.should == @issue.to_xml
      end

      it "should not return a processing issue" do
        @processing_issue = Factory(:issue_being_processed, :account => @account)
        get "/issues/#{@processing_issue.id}.xml"

        last_response.should be_not_found
      end
    end

    describe "GET to /issues/id/articles.xml" do
      before do
        @issue = Factory(:issue, :account => @account)
        @published_articles = (1..3).collect{ Factory(:detailed_article, :account => @account, :issues => [@issue]) }
      end

      it "should return all of this issues published articles" do
        get "/issues/#{@issue.id}/articles.xml"

        last_response.should be_ok
        last_response.headers['Content-Type'].should == "text/xml"
        last_response.body.should == @issue.articles.published.by_published_at(:desc).to_xml
      end

      it "should not return unpublished articles" do
        @unpublished_article = Factory(:draft_article, :account => @account, :issues => [@issue]) 
        get "/issues/#{@issue.id}/articles.xml"

        last_response.body.should == @issue.articles.published.by_published_at(:desc).to_xml
      end

      it "should return only articles from a certain section, if requested" do
        category = Factory(:category, :account => @account)
        category_articles = (1..4).collect{ Factory(:detailed_article, :account => @account, :issues => [@issue], :section => category) }      
        get "/issues/#{@issue.id}/articles.xml", :section_id => category.id

        last_response.body.should == @issue.articles.in_section(category).by_date_published.to_xml  
      end
    end

  end

  describe "Blogs" do
    describe "GET to /blogs.xml" do
      it "should return an array of blogs" do
        @blogs = (1..4).collect{ Factory(:blog, :account => @account, :status => true) }
        @inactive_blogs = (1..4).collect{ Factory(:blog, :account => @account, :status => false) }        
        get "/blogs.xml"

        last_response.should be_ok
        last_response.headers['Content-Type'].should == "text/xml"
        last_response.body.should == @account.blogs.active.to_xml
      end
    end

    describe "GET to /blogs/:id.xml" do
      it "should return an xml representation of the blog" do
        @blog = Factory(:blog, :account => @account)
        get "/blogs/#{@blog.id}.xml"

        last_response.should be_ok
        last_response.headers['Content-Type'].should == "text/xml"
        last_response.body.should == @blog.to_xml
      end
    end

    describe "GET to /entries.xml" do
      before do
        @blog_one = Factory(:blog, :account => @account)
        @blog_two = Factory(:blog, :account => @account)
        @blog_one_entries = (1..3).collect{ |n| Factory(:detailed_entry, :account => @account, :blog => @blog_one) }
        @blog_two_entries = (1..3).collect{ |n|  Factory(:detailed_entry, :account => @account, :blog => @blog_two) }
      end

      it "should return an array of the most recent entries from any blog" do
        get "/entries.xml"

        last_response.should be_ok
        last_response.headers['Content-Type'].should == "text/xml"
        last_response.body.should == @account.entries.paginate(:page => 1, :per_page => 20, :order => "published_at DESC", :conditions => { :status => "published" }).to_xml
      end

      it "should return entries by blog" do
        get "/entries.xml", :blog_id => @blog_one.id

        last_response.should be_ok
        last_response.headers['Content-Type'].should == "text/xml" 
        last_response.body.should == @blog_one.entries.paginate(:page => 1, :per_page => 20, :order => "published_at DESC", :conditions => { :status => "published" }).to_xml       
      end 
    end

    describe "GET to /entries/id.xml" do
      it "should return an XML representation of the entry" do
        @entry = Factory(:detailed_entry, :account => @account)
        get "/entries/#{@entry.id}.xml"

        last_response.should be_ok
        last_response.headers['Content-Type'].should == "text/xml"
        last_response.body.should == @entry.to_xml
      end
    end

  end

  describe "Query" do
    describe "GET to /query.xml" do
      it "should return latest articles by section" do
        section_one = Factory(:category, :account => @account)
        section_two = Factory(:category, :account => @account)
        section_one_articles = (1..5).collect{ Factory(:article, :account => @account, :section => section_one) }
        section_two_articles = (1..5).collect{ Factory(:article, :account => @account, :section => section_two) }
        section_two_scheduled = Factory(:scheduled_article, :account => @account, :section => section_two)

        get "/query.xml", :group_by => "section"

        last_response.should be_ok
        last_response.headers['Content-Type'].should == "text/xml"
        last_response.body.should == (@account.articles.in_section(section_one).published.by_date_published.limited(5) + @account.articles.in_section(section_two).published.by_date_published.limited(5)).to_xml
      end

      it "should return latest entries by blog" do
        blog_one = Factory(:blog, :account => @account)
        blog_two = Factory(:blog, :account => @account)
        blog_one_entries = (1..5).collect{ Factory(:detailed_entry, :account => @account, :blog => blog_one) }
        blog_two_entries = (1..5).collect{ Factory(:detailed_entry, :account => @account, :blog => blog_two) }
        blog_one_scheduled = Factory(:scheduled_entry, :account => @account, :blog => blog_one)

        get "/query.xml", :group_by => "blog"

        last_response.should be_ok
        last_response.headers['Content-Type'].should == "text/xml"

        options = { :conditions => { :status => 'published' }, :limit => 5, :order => "published_at DESC" }
        last_response.body.should == (blog_one.entries.published.all(options) + blog_two.entries.published.all(options)).to_xml  
      end
    end
  end
end