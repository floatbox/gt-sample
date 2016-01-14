object @review

attributes :id, :impression, :description, :name
node(:user_pic){ nil }
node(:posted_on){ |r| r.created_at.to_i * 1000 }
