# -*- coding: utf-8 -*-

require 'celluloid'

module Vnet::Openflow

  class NetworkManager < Vnet::Manager
    include UpdateItemStates

    #
    # Events:
    #
    
    # Networks have no created item event as they always get loaded
    # when used by other managers.
    subscribe_event NETWORK_INITIALIZED, :install_item
    subscribe_event NETWORK_UNLOAD_ITEM, :unload_item
    subscribe_event NETWORK_DELETED_ITEM, :unload_item

    subscribe_event NETWORK_UPDATE_ITEM_STATES, :update_item_states

    def initialize(*args)
      super
      @interface_ports = {}
      @interface_networks = {}
    end

    #
    # Interfaces:
    #

    def set_interface_port(interface_id, port)
      @interface_ports[interface_id] = port
      networks = @interface_networks[interface_id]

      add_item_ids_to_update_queue(networks) if networks
    end

    def clear_interface_port(interface_id)
      port = @interface_ports.delete(interface_id) || return
      networks = @interface_networks[interface_id]

      add_item_ids_to_update_queue(networks) if networks
    end

    def insert_interface_network(interface_id, network_id)
      networks = @interface_networks[interface_id] ||= []
      return if networks.include? network_id

      networks << network_id
      add_item_id_to_update_queue(network_id) if @interface_ports[interface_id]
    end

    def remove_interface_network(interface_id, network_id)
      networks = @interface_networks[interface_id] || return
      return unless networks.delete(network_id)

      add_item_id_to_update_queue(network_id) if @interface_ports[interface_id]
    end

    # TODO: Clear port from port manager.
    def remove_interface_from_all(interface_id)
      networks = @interface_networks.delete(interface_id)
      port = @interface_ports.delete(interface_id)

      return unless networks && port

      add_item_ids_to_update_queue(networks)
    end

    #
    # Internal methods:
    #

    private

    #
    # Specialize Manager:
    #

    def mw_class
      MW::Network
    end

    def initialized_item_event
      NETWORK_INITIALIZED
    end

    def item_unload_event
      NETWORK_UNLOAD_ITEM
    end

    def update_item_states_event
      NETWORK_UPDATE_ITEM_STATES
    end

    def match_item?(item, params)
      return false if params[:id] && params[:id] != item.id
      return false if params[:uuid] && params[:uuid] != item.uuid

      # Clean up use of this parameter.
      return false if params[:network_type] && params[:network_type] != item.network_type
      return false if params[:network_mode] && params[:network_mode] != item.network_type
      true
    end

    def query_filter_from_params(params)
      filter = []
      filter << {id: params[:id]} if params.has_key? :id
      filter
    end

    def select_filter_from_params(params)
      return nil if params.has_key?(:uuid) && params[:uuid].nil?

      create_batch(mw_class.batch, params[:uuid], query_filter_from_params(params))
    end

    def item_initialize(item_map, params)
      item_class =
        case item_map.network_mode
        when 'physical' then Networks::Physical
        when 'virtual'  then Networks::Virtual
        else
          error log_format('unknown network type',
                           "network_mode:#{item_map.network_mode}")
          return nil
        end

      item_class.new(dp_info: @dp_info, map: item_map)
    end

    #
    # Create / Delete events:
    #

    # NETWORK_INITIALIZED on queue 'item.id'.
    def install_item(params)
      item_map = params[:item_map] || return
      item = @items[item_map.id] || return

      debug log_format("install #{item_map.uuid}/#{item_map.id}")

      item.try_install

      add_item_id_to_update_queue(item.id)

      @dp_info.datapath_manager.publish(ACTIVATE_NETWORK_ON_HOST,
                                        id: :network,
                                        network_id: item.id)
      @dp_info.route_manager.publish(ROUTE_ACTIVATE_NETWORK,
                                     id: :network,
                                     network_id: item.id)

      @dp_info.interface_manager.load_simulated_on_network_id(item.id)
    end

    # NETWORK_CREATED_ITEM is not needed.

    # NETWORK_UNLOAD_ITEM on queue 'item.id'.
    # NETWORK_DELETED_ITEM on queue 'item.id'.
    def unload_item(params)
      item = @items.delete(item[:id]) || return

      @dp_info.datapath_manager.publish(DEACTIVATE_NETWORK_ON_HOST,
                                        id: :network,
                                        network_id: item.id)
      @dp_info.route_manager.publish(ROUTE_DEACTIVATE_NETWORK,
                                     id: :network,
                                     network_id: item.id)

      item.try_uninstall

      debug log_format("unloaded network #{item.uuid}/#{item.id}")
    end

    #
    # Event handlers:
    #

    # Requires queue ':update_item_states'
    def update_item_state(item)
      item.update_flows(port_numbers_on_network(item.id))
    end

    #
    # Helper methods:
    #

    def port_numbers_on_network(network_id)
      port_numbers = []

      @interface_networks.each { |interface_id, networks|
        next unless networks.include? network_id
        
        port_numbers << (@interface_ports[interface_id] || next)
      }

      port_numbers
    end

  end

end
