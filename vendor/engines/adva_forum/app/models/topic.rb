class Topic < ActiveRecord::Base
  has_permalink :title
  acts_as_commentable :polymorphic => true

  acts_as_role_context :roles => :author, :implicit_roles => lambda{|user|
    comments.by_author(user).map{|comment| Role.build :author, comment }
  }

  belongs_to :site
  belongs_to :section
  belongs_to_author :last_author   
  belongs_to :last_comment, :class_name => 'Comment', :foreign_key => :last_comment_id

  before_validation :set_site  

  validates_presence_of :section, :title
  validates_presence_of :body, :on => :create

  attr_accessor :body  
  delegate :comment_filter, :to => :site

  class << self
    def post(author, attributes)
      topic = Topic.new attributes
      topic.last_author = author
      topic.reply author, :body => attributes[:body]
      # revise topic, attributes
      topic
    end
  end
  
  def owner
    section
  end
    
  def reply(author, attributes)
    returning comments.build(attributes) do |comment|
      comment.author = author
      comment.commentable = self
    end
  end
  
  def revise(author, attributes)
    self.sticky, self.locked = attributes.delete(:sticky), attributes.delete(:locked) # if author.has_permission ...
    self.update_attributes attributes
  end  
  
  # def hit!
  #   self.class.increment_counter :hits, id
  # end
  
  def accept_comments?
    !locked?
  end

  def paged?
    comments_count > @section.articles_per_page
  end
  
  def last_page
    @last_page ||= [(comments_count.to_f / section.articles_per_page.to_f).ceil.to_i, 1].max
  end

  def previous
    section.topics.find :first, :conditions => ['last_updated_at < ?', last_updated_at], :order => :last_updated_at
  end

  def next
    section.topics.find :first, :conditions => ['last_updated_at > ?', last_updated_at], :order => :last_updated_at
  end
  
  def after_comment_update(comment)
    if comment = comment.frozen? ? comments.last_one : comment
      update_attributes! :last_updated_at => comment.created_at,
                         :last_comment_id => comment.id,
                         :last_author => comment.author,
                         :comments_count => comments.count
    else
      self.destroy
    end
    # section.after_topic_update(self)
  end

  protected
    def set_site
      # TODO why not just always set the site_id? and in what cases would the section be nil?
      self.site_id = section.site_id # if site_id.nil? && section
    end
end