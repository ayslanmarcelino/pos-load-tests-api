class User < ApplicationRecord
  belongs_to :company

  validates :email, uniqueness: true
end
