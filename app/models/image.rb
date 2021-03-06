class Image < Mediafile
  
  before_save :save_dimensions 
  
  has_attached_file :file,
      :styles => {
        :system_icon => [ "x20>", 'jpg' ],
        :system_thumb => ["100x56>", 'jpg'],
        :thumb  => [ Proc.new { |instance| instance.settings["thumb"].first }, 'jpg'],
        :small => [ Proc.new { |instance| instance.settings["small"].first }, 'jpg'],
        :medium => [ Proc.new { |instance| instance.settings["medium"].first }, 'jpg'],
        :system_default => ["400>", 'jpg'],
        :large => [ Proc.new { |instance| instance.settings["large"].first }, 'jpg']
      },
      :convert_options => {
        :all => "-colorspace RGB -strip"
      },
      :default_style => :system_default,
      :path => ":rails_root/public/system/:account/:class/:id_partition/:basename_:style.:extension",
      :url => "/system/:account/:class/:id_partition/:basename_:style.:extension"
      
  validates_attachment_presence :file
  
  attr_accessor :settings
  
  def image?
    true
  end
  
  def file?
    false
  end
  
  def save_dimensions 
    self.width = Paperclip::Geometry.from_file(file.to_file(:original)).width 
    self.height = Paperclip::Geometry.from_file(file.to_file(:original)).height  
  end
  
  def height_for_style(style)
    geometry_for(style).height.to_i
  end
  
  def width_for_style(style)
    geometry_for(style).width.to_i
  end
  
  # Returns Paperclip::Geometry instance created from a given style's file
  def geometry_for(style)
    Paperclip::Geometry.from_file(file.to_file(style))
  end
  
  def to_xml(options = {})
     options[:indent] ||= 2
     caption = options[:caption] || self.description
     xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
     xml.instruct! unless options[:skip_instruct]
     
     xml.mediafile do
       xml.tag!( :title, self.title )
       xml.tag!( :caption, caption)
       xml.tag!( :mediafile_type, read_attribute(:type) || "Mediafile" )
       xml.tag!( :date, self.date )
       xml.tag!( :authors_list, self.authors_list )
       xml.url do
         xml.tag!(:original, self.file.url(:original))
         xml.tag!(:thumb, self.file.url(:thumb) )
         xml.tag!(:small, self.file.url(:small))
         xml.tag!(:medium, self.file.url(:medium))
         xml.tag!(:large, self.file.url(:large) )
         xml.tag!(:system_default, self.file.url(:system_default) )
         xml.tag!(:system_thumb, self.file.url(:system_thumb) )
         xml.tag!(:system_icon, self.file.url(:system_icon) )
       end
       xml.tag!( :content_type, self.file_content_type )
       xml.tag!( :original_file_size, number_to_human_size(self.file_file_size) )
       xml.tag!( :id, self.id )
       xml.tag!( :width, self.width)
       xml.tag!( :height, self.height)       
     end
  end
  
end
