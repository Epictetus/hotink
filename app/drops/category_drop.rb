class CategoryDrop < Drop
  
  alias_method :category, :source # for readability
  
  liquid_attributes :name, :slug, :path
  
  def subcategories
    category.children.collect{ |child| CategoryDrop.new(child) }
  end
  
  def subcategory
    subcategories = {}
    category.children.each do |category|
      subcategories[category.name] = CategoryDrop.new(category)
    end
    subcategories
  end
  
  def articles
    category.articles.published.find(:all, :limit => 20).collect{ |a| ArticleDrop.new(a)  }
  end
  
end