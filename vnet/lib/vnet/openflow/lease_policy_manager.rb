# -*- coding: utf-8 -*-

module Vnet::Openflow

  class LeasePolicyManager < Manager

    #
    # Events:
    #
    subscribe_event ADDED_LEASE_POLICY, :create_item
    subscribe_event REMOVED_LEASE_POLICY, :delete_item
    subscribe_event INITIALIZED_LEASE_POLICY, :install_item

    def update(params)
      nil
    end

    #
    # Internal methods:
    #

    private

    #
    # Specialize Manager:
    #

    def select_item(filter)
      MW::LeasePolicy.batch[filter].commit
    end

    def item_initialize(item_map, params)
      LeasePolicies::Base.new(dp_info: @dp_info, manager: self, map: item_map)
    end

    def initialized_item_event
      INITIALIZED_LEASE_POLICY
    end

    def create_item(params)
      item = @items[params[:item_map].id]
      return unless item

      debug log_format("insert #{item.uuid}/#{item.id}")
      item
    end

    def install_item(params)
      item = @items[params[:item_map].id]
      return nil if item.nil?

      item.install

      debug log_format("install #{item.uuid}/#{item.id}")
      item
    end

    def delete_item(item)
      @items.delete(item.id)

      item.uninstall
      item
    end

    #
    # Events:
    #

  end

end
