class FoursquareTip < Struct.new(:created_at, :text, :foursquare_uid)
  def self.venue_tips_for(foursquare_uid)
    client = Foursquare2::Client.new :client_id => 'RYP0YOQ5XX1YOAWFM3SDHVKSGVQ54BAM1XHUABYJBVE3WALM',
      :client_secret => 'ML4SGPTGI0YFMWTZLNQABKKRU1LAE3UE4ZE5WT3LFXF2PEUV',
      :api_version => '20151010',
      :ssl => { :ca_file => "#{Rails.root}/config/ca-bundle.crt" }
    client.venue_tips(foursquare_uid).items.map{ |tip| FoursquareTip.new(tip.createdAt, tip.text, foursquare_uid) }
  rescue
    []
  end
end
