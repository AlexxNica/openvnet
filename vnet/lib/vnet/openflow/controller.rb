# -*- coding: utf-8 -*-

require 'racket'
require 'trema/actions'
require 'trema/instructions'
require 'trema/messages'

module Vnet::Openflow

  class Controller < Trema::Controller
    include TremaTasks
    include Celluloid::Logger

    attr_reader :switches
    attr_accessor :trema_thread

    def initialize(service_openflow)
      @service_openflow = service_openflow

      @switches = {}
    end

    def start
      info "starting OpenFlow controller."
    end

    def switch_ready(dpid)
      info "switch_ready from %#x." % dpid

      # Sometimes ovs changes the datapath ID and reconnects.
      old_switch = @switches.delete(dpid)
      
      if old_switch
        info "found old bridge: dpid:%016x" % dpid

        #old_switch[1].networks.each { |network_id,network| @service_openflow.destroy_network(network, false) }
      end

      # There is no need to clean up the old switch, as all the
      # previous flows are removed. Just let it rebuild everything.
      #
      # This might not be optimal in cases where the switch got
      # disconnected for a short period, as Open vSwitch has the
      # ability to keep flows between sessions.
      switch = switches[dpid] = Switch.new(Datapath.new(self, dpid, OvsOfctl.new(dpid)))
      switch.async.switch_ready
    end

    def features_reply(dpid, message)
      info "features_reply from %#x." % dpid

      switch = switches[dpid] || raise("No switch found.")
      switch.async.features_reply(message)
    end

    def port_desc_multipart_reply(dpid, message)
      info "port_desc_multipart_reply from %#x." % dpid

      switch = switches[dpid] || raise("No switch found.")

      message.parts.each { |port_descs| 
        port_descs.ports.each { |port_desc| 
          switch.async.update_bridge_hw(port_desc.hw_addr.dup) if port_desc.name =~ /^eth/
        }
      }

      message.parts.each { |port_descs| 
        debug "ports: %s" % port_descs.ports.collect { |each| each.port_no }.sort.join( ", " )

        port_descs.ports.each { |port_desc| switch.async.handle_port_desc(port_desc) }
      }
      
    end

    def port_status(dpid, message)
      debug "port_status from %#x." % dpid

      switch = switches[dpid] || raise("No switch found.")
      switch.async.port_status(message)
    end

    def packet_in(dpid, message)
      switch = switches[dpid] || raise("No switch found.")
      switch.async.packet_in(message)
    end

    def vendor(dpid, message)
      debug "vendor message from #{dpid.to_hex}."
      debug "transaction_id: #{message.transaction_id.to_hex}"
      debug "data: #{message.buffer.unpack('H*')}"
    end

    def public_send_message(dpid, message)
      raise "public_send_message must be called from the trema thread" unless Thread.current == @trema_thread
      send_message(dpid, message)
    end

    def public_send_flow_mod(dpid, message)
      raise "public_send_flow_mod must be called from the trema thread" unless Thread.current == @trema_thread
      send_flow_mod(dpid, message)
    end

    def public_send_packet_out(dpid, message, port_no)
      raise "public_send_packet_out must be called from the trema thread" unless Thread.current == @trema_thread
      send_packet_out(dpid, {
                        :packet_in => message,
                        :actions => [Trema::Actions::SendOutPort.new(:port_number => port_no)]
                      })
    end

  end

end