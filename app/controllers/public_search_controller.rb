class PublicSearchController < PublicController
    
  def show
    if @design = design_to_render
      if params[:q]
        @hits = @account.articles.search(@search_query)
      else
        @hits = []
      end
      render :text => @design.search_results_template.render({'search_results' => @hits.collect{ |a| SearchResultDrop.new(a) }, 'query' => params[:q], 'content' => ContentDrop.new(@account), 'site' => SiteDrop.new}, :registers => { :design => @design }) 
    else
      render :text => "This site is currently offline.", :status => :service_unavailable
    end
  end
  
end
