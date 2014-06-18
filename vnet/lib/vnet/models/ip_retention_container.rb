module Vnet::Models
  class IpRetentionContainer < Base
    taggable 'irc'

    one_to_many :ip_retentions

    one_to_many :lease_policy_ip_retention_containers
    many_to_many :lease_policies, :join_table => :lease_policy_ip_retention_containers

    plugin :association_dependencies,
      lease_policy_ip_retention_containers: :destroy

    def validate
      super
      errors.add(:lease_time, 'cannot be less than 0') if grace_time && grace_time < 0
      errors.add(:grace_time, 'cannot be less than 0') if grace_time && grace_time < 0
    end
  end
end
