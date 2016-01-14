class TaggedItem < ActiveRecord::Base
  belongs_to :tag
  belongs_to :item, :polymorphic => true
end