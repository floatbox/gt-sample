class SiteLanding < Landing
  include SiteLandingPresenter

  SEO_FIELDS = %w( title description link_title meta_title meta_description landing_description )

  KINDS = %w( search landing index iphone )

  has_attached_file :panel_photo, { :styles => { :main => ['1400x420#', 'jpg'] },
                                    :path => "landings/:id/:style.jpg" }.merge(PAPERCLIP_STORAGE_OPTIONS)
  validates_presence_of :kind, :permalink
  validates_uniqueness_of :permalink, :scope => :city_id
  validates_inclusion_of :kind, :in => KINDS
  validates_attachment_content_type :panel_photo, :content_type => /image/

  before_save :renew_seo_updated_at, :if => lambda{ |l| SEO_FIELDS.map{ |f| l.send("#{f}_changed?") }.include?(true) }

  named_scope :permalink, lambda { |permalink| { :conditions => ['permalink = ?', permalink] } }
  named_scope :cuisine, :conditions => "permalink LIKE '%cuisine%'"
  named_scope :network, :conditions => "permalink LIKE '%network%'"
  # named_scope :mode,    :conditions => "permalink LIKE '%metro%'"
  named_scope :metro,   :conditions => "permalink LIKE '%metro%'"
  named_scope :common,  :conditions => "permalink LIKE '%feature%' OR permalink LIKE '%offer%'"
  named_scope :not_index, :conditions => ['kind != ?', 'index']
  named_scope :for_footer, :conditions => "footer_link = TRUE"

  %w(meta_title meta_description landing_description).each do |field|
    named_scope "with_#{field}".to_sym, :conditions => ["#{field} IS NOT NULL AND #{field} != ''"]
    named_scope "without_#{field}".to_sym, :conditions => ["#{field} IS NULL OR #{field} = ''"]
  end

  def bread_crumbs(crumbs = [])
    crumbs.unshift(self)
    parent ? parent.bread_crumbs(crumbs) : crumbs
  end

  def bread_crumbs_serialized
    bread_crumbs.map{ |bc| { :title => bc.link_title, :link => bc.link } }
  end

  def label
    link_title || title
  end

private

  def renew_seo_updated_at
    self.seo_updated_at = Time.zone.now
  end

end
